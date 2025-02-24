## Waku Store protocol for historical messaging support.
## See spec for more details:
## https://github.com/vacp2p/specs/blob/master/specs/waku/v2/waku-store.md
{.push raises: [Defect].}

import
  std/[tables, times, sequtils, options],
  stew/results,
  chronicles,
  chronos, 
  bearssl/rand,
  libp2p/crypto/crypto,
  libp2p/protocols/protocol,
  libp2p/protobuf/minprotobuf,
  libp2p/stream/connection,
  metrics
import
  ../../node/storage/message/message_store,
  ../../node/storage/message/message_retention_policy,
  ../../node/storage/message/waku_store_queue,
  ../../node/peer_manager/peer_manager,
  ../../utils/time,
  ../../utils/pagination,
  ../../utils/requests,
  ../waku_message,
  ../waku_swap/waku_swap,
  ./rpc,
  ./rpc_codec


declarePublicGauge waku_store_messages, "number of historical messages", ["type"]
declarePublicGauge waku_store_peers, "number of store peers"
declarePublicGauge waku_store_errors, "number of store protocol errors", ["type"]
declarePublicGauge waku_store_queries, "number of store queries received"
declarePublicHistogram waku_store_insert_duration_seconds, "message insertion duration"
declarePublicHistogram waku_store_query_duration_seconds, "history query duration"

logScope:
  topics = "wakustore"


const 
  WakuStoreCodec* = "/vac/waku/store/2.0.0-beta4"

  DefaultTopic* = "/waku/2/default-waku/proto"

  MaxMessageTimestampVariance* = Timestamp(20.seconds.nanoseconds) # 20 seconds maximum allowable sender timestamp "drift"


# Error types (metric label values)
const
  insertFailure = "insert_failure"
  retPolicyFailure = "retpolicy_failure"
  dialFailure = "dial_failure"
  decodeRpcFailure = "decode_rpc_failure"
  peerNotFoundFailure = "peer_not_found_failure"


type
  WakuStoreResult*[T] = Result[T, string]

  WakuStore* = ref object of LPProtocol
    peerManager*: PeerManager
    rng*: ref rand.HmacDrbgContext
    store*: MessageStore
    wakuSwap*: WakuSwap
    retentionPolicy: Option[MessageRetentionPolicy]


proc executeMessageRetentionPolicy*(w: WakuStore) =
  if w.retentionPolicy.isNone():
    return

  if w.store.isNil():
    return

  let policy = w.retentionPolicy.get()

  let retPolicyRes = policy.execute(w.store)
  if retPolicyRes.isErr():
      waku_store_errors.inc(labelValues = [retPolicyFailure])
      debug "failed execution of retention policy", error=retPolicyRes.error


proc reportStoredMessagesMetric*(w: WakuStore) = 
  if w.store.isNil():
    return

  let resCount = w.store.getMessagesCount()
  if resCount.isErr():
    return

  waku_store_messages.set(resCount.value, labelValues = ["stored"])


proc findMessages(w: WakuStore, query: HistoryQuery): HistoryResponse {.gcsafe.} =
  ## Query history to return a single page of messages matching the query
  
  # Extract query criteria. All query criteria are optional
  let
    qContentTopics = if (query.contentFilters.len != 0): some(query.contentFilters.mapIt(it.contentTopic))
                     else: none(seq[ContentTopic])
    qPubSubTopic = if (query.pubsubTopic != ""): some(query.pubsubTopic)
                   else: none(string)
    qCursor = if query.pagingInfo.cursor != Index(): some(query.pagingInfo.cursor)
              else: none(Index)
    qStartTime = if query.startTime != Timestamp(0): some(query.startTime)
                 else: none(Timestamp)
    qEndTime = if query.endTime != Timestamp(0): some(query.endTime)
               else: none(Timestamp)
    qMaxPageSize = query.pagingInfo.pageSize
    qAscendingOrder = query.pagingInfo.direction == PagingDirection.FORWARD


  let queryStartTime = getTime().toUnixFloat()
  
  let queryRes = w.store.getMessagesByHistoryQuery(
        contentTopic = qContentTopics,
        pubsubTopic = qPubSubTopic,
        cursor = qCursor,
        startTime = qStartTime,
        endTime = qEndTime,
        maxPageSize = qMaxPageSize,
        ascendingOrder = qAscendingOrder
      )

  let queryDuration = getTime().toUnixFloat() - queryStartTime
  waku_store_query_duration_seconds.observe(queryDuration)


  # Build response
  # TODO: Improve error reporting
  if queryRes.isErr():
    return HistoryResponse(messages: @[], pagingInfo: PagingInfo(), error: HistoryResponseError.INVALID_CURSOR)

  let (messages, updatedPagingInfo) = queryRes.get()
  
  HistoryResponse(
    messages: messages, 
    pagingInfo: updatedPagingInfo.get(PagingInfo()),
    error: HistoryResponseError.NONE
  )

proc initProtocolHandler*(ws: WakuStore) =
  
  proc handler(conn: Connection, proto: string) {.async.} =
    let buf = await conn.readLp(MaxRpcSize.int)

    let resReq = HistoryRPC.init(buf)
    if resReq.isErr():
      error "failed to decode rpc", peerId=conn.peerId
      waku_store_errors.inc(labelValues = [decodeRpcFailure])
      return

    let req = resReq.value

    info "received history query", peerId=conn.peerId, requestId=req.requestId, query=req.query
    waku_store_queries.inc()

    let resp = if not ws.store.isNil(): ws.findMessages(req.query)
               # TODO: Improve error reporting
               else: HistoryResponse(error: HistoryResponseError.SERVICE_UNAVAILABLE)

    if not ws.wakuSwap.isNil():
      info "handle store swap", peerId=conn.peerId, requestId=req.requestId, text=ws.wakuSwap.text

      # Perform accounting operation
      # TODO: Do accounting here, response is HistoryResponse. How do we get node or swap context?
      let peerId = conn.peerId
      let messages = resp.messages
      ws.wakuSwap.credit(peerId, messages.len)

    info "sending history response", peerId=conn.peerId, requestId=req.requestId, messages=resp.messages.len

    let rpc = HistoryRPC(requestId: req.requestId, response: resp)
    await conn.writeLp(rpc.encode().buffer)

  ws.handler = handler
  ws.codec = WakuStoreCodec

proc init*(T: type WakuStore, 
           peerManager: PeerManager, 
           rng: ref rand.HmacDrbgContext,
           store: MessageStore, 
           wakuSwap: WakuSwap = nil, 
           retentionPolicy=none(MessageRetentionPolicy)): T =
  let ws = WakuStore(
    rng: rng, 
    peerManager: peerManager, 
    store: store, 
    wakuSwap: wakuSwap, 
    retentionPolicy: retentionPolicy
  )
  ws.initProtocolHandler()

  return ws

proc init*(T: type WakuStore, 
           peerManager: PeerManager, 
           rng: ref rand.HmacDrbgContext,
           wakuSwap: WakuSwap = nil, 
           retentionPolicy=none(MessageRetentionPolicy)): T =
  let store = StoreQueueRef.new()
  WakuStore.init(peerManager, rng, store, wakuSwap, retentionPolicy)


proc handleMessage*(w: WakuStore, pubsubTopic: string, msg: WakuMessage) =
  if w.store.isNil():
    # Messages should not be stored
    return

  if msg.ephemeral:
    # The message is ephemeral, should not be stored
    return
  
  let insertStartTime = getTime().toUnixFloat()
    
  let now = getNanosecondTime(getTime().toUnixFloat())
  let index = Index.compute(msg, receivedTime=now, pubsubTopic=pubsubTopic)

  trace "handling message", topic=pubsubTopic, index=index

  # Add messages to persistent store, if present
  let putStoreRes = w.store.put(index, msg, pubsubTopic)
  if putStoreRes.isErr():
    debug "failed to insert message to persistent store", index=index, err=putStoreRes.error
    waku_store_errors.inc(labelValues = [insertFailure])
    return

  let insertDuration = getTime().toUnixFloat() - insertStartTime
  waku_store_insert_duration_seconds.observe(insertDuration)


## CLIENT

# TODO: This should probably be an add function and append the peer to an array
proc setPeer*(ws: WakuStore, peer: RemotePeerInfo) =
  ws.peerManager.addPeer(peer, WakuStoreCodec)
  waku_store_peers.inc()

proc query(w: WakuStore, req: HistoryQuery, peer: RemotePeerInfo): Future[WakuStoreResult[HistoryResponse]] {.async, gcsafe.} =
  let connOpt = await w.peerManager.dialPeer(peer, WakuStoreCodec)
  if connOpt.isNone():
    waku_store_errors.inc(labelValues = [dialFailure])
    return err(dialFailure)
  let connection = connOpt.get()

  let rpc = HistoryRPC(requestId: generateRequestId(w.rng), query: req)
  await connection.writeLP(rpc.encode().buffer)

  var message = await connOpt.get().readLp(MaxRpcSize.int)
  let response = HistoryRPC.init(message)

  if response.isErr():
    error "failed to decode response"
    waku_store_errors.inc(labelValues = [decodeRpcFailure])
    return err(decodeRpcFailure)

  waku_store_messages.set(response.value.response.messages.len.int64, labelValues = ["retrieved"])
  return ok(response.value.response)

proc query*(w: WakuStore, req: HistoryQuery): Future[WakuStoreResult[HistoryResponse]] {.async, gcsafe.} =
  # TODO: We need to be more stratigic about which peers we dial. Right now we just set one on the service.
  # Ideally depending on the query and our set  of peers we take a subset of ideal peers.
  # This will require us to check for various factors such as:
  #  - which topics they track
  #  - latency?
  #  - default store peer?

  let peerOpt = w.peerManager.selectPeer(WakuStoreCodec)
  if peerOpt.isNone():
    error "no suitable remote peers"
    waku_store_errors.inc(labelValues = [peerNotFoundFailure])
    return err(peerNotFoundFailure)

  return await w.query(req, peerOpt.get())


## 21/WAKU2-FAULT-TOLERANT-STORE

const StoreResumeTimeWindowOffset: Timestamp = getNanosecondTime(20)  ## Adjust the time window with an offset of 20 seconds

proc queryFromWithPaging*(w: WakuStore, query: HistoryQuery, peer: RemotePeerInfo): Future[WakuStoreResult[seq[WakuMessage]]] {.async, gcsafe.} =
  ## A thin wrapper for query. Sends the query to the given peer. when the  query has a valid pagingInfo, 
  ## it retrieves the historical messages in pages.
  ## Returns all the fetched messages, if error occurs, returns an error string

  # Make a copy of the query
  var req = query

  var messageList: seq[WakuMessage] = @[]

  # Fetch the history in pages
  while true:
    let res = await w.query(req, peer)
    if res.isErr(): 
      return err(res.error)

    let response = res.get()

    messageList.add(response.messages)

    # Check whether it is the last page
    if response.pagingInfo.pageSize == 0:
      break

    # Update paging cursor
    req.pagingInfo.cursor = response.pagingInfo.cursor

  return ok(messageList)

proc queryLoop(w: WakuStore, req: HistoryQuery, candidateList: seq[RemotePeerInfo]): Future[WakuStoreResult[seq[WakuMessage]]]  {.async, gcsafe.} = 
  ## Loops through the peers candidate list in order and sends the query to each
  ##
  ## Once all responses have been received, the retrieved messages are consolidated into one deduplicated list.
  ## if no messages have been retrieved, the returned future will resolve into a result holding an empty seq.
  let queriesList = candidateList.mapIt(w.queryFromWithPaging(req, it))

  await allFutures(queriesList)

  let messagesList = queriesList
    .map(proc (fut: Future[WakuStoreResult[seq[WakuMessage]]]): seq[WakuMessage] =
      # These futures have been awaited before using allFutures(). Call completed() just as a sanity check. 
      if not fut.completed() or fut.read().isErr(): 
        return @[]

      fut.read().value
    )
    .concat()
    .deduplicate()

  if messagesList.len == 0:
    return err("failed to resolve the query")

  return ok(messagesList)

proc resume*(w: WakuStore, 
             peerList: Option[seq[RemotePeerInfo]] = none(seq[RemotePeerInfo]), 
             pageSize: uint64 = DefaultPageSize,
             pubsubTopic = DefaultTopic): Future[WakuStoreResult[uint64]] {.async, gcsafe.} =
  ## resume proc retrieves the history of waku messages published on the default waku pubsub topic since the last time the waku store node has been online 
  ## messages are stored in the store node's messages field and in the message db
  ## the offline time window is measured as the difference between the current time and the timestamp of the most recent persisted waku message 
  ## an offset of 20 second is added to the time window to count for nodes asynchrony
  ## peerList indicates the list of peers to query from.
  ## The history is fetched from all available peers in this list and then consolidated into one deduplicated list.
  ## Such candidates should be found through a discovery method (to be developed).
  ## if no peerList is passed, one of the peers in the underlying peer manager unit of the store protocol is picked randomly to fetch the history from. 
  ## The history gets fetched successfully if the dialed peer has been online during the queried time window.
  ## the resume proc returns the number of retrieved messages if no error occurs, otherwise returns the error string
  
  # If store has not been provided, don't even try
  if w.store.isNil():
    return err("store not provided (nil)")

  # NOTE: Original implementation is based on the message's sender timestamp. At the moment
  #       of writing, the sqlite store implementation returns the last message's receiver 
  #       timestamp.
  #  lastSeenTime = lastSeenItem.get().msg.timestamp
  let 
    lastSeenTime = w.store.getNewestMessageTimestamp().get(Timestamp(0))
    now = getNanosecondTime(getTime().toUnixFloat())

  debug "resuming with offline time window", lastSeenTime=lastSeenTime, currentTime=now

  let
    queryEndTime = now + StoreResumeTimeWindowOffset
    queryStartTime = max(lastSeenTime - StoreResumeTimeWindowOffset, 0)

  let req = HistoryQuery(
    pubsubTopic: pubsubTopic, 
    startTime: queryStartTime, 
    endTime: queryEndTime,
    pagingInfo: PagingInfo(
      direction:PagingDirection.FORWARD, 
      pageSize: pageSize
    )
  )

  var res: WakuStoreResult[seq[WakuMessage]]
  if peerList.isSome():
    debug "trying the candidate list to fetch the history"
    res = await w.queryLoop(req, peerList.get())

  else:
    debug "no candidate list is provided, selecting a random peer"
    # if no peerList is set then query from one of the peers stored in the peer manager 
    let peerOpt = w.peerManager.selectPeer(WakuStoreCodec)
    if peerOpt.isNone():
      warn "no suitable remote peers"
      waku_store_errors.inc(labelValues = [peerNotFoundFailure])
      return err("no suitable remote peers")

    debug "a peer is selected from peer manager"
    res = await w.queryFromWithPaging(req, peerOpt.get())

  if res.isErr(): 
    debug "failed to resume the history"
    return err("failed to resume the history")


  # Save the retrieved messages in the store
  var added: uint = 0
  for msg in res.get():
    let now = getNanosecondTime(getTime().toUnixFloat())
    let index = Index.compute(msg, receivedTime=now, pubsubTopic=pubsubTopic)

    let putStoreRes = w.store.put(index, msg, pubsubTopic)
    if putStoreRes.isErr():
      continue

    added.inc()

  return ok(added)


## EXPERIMENTAL

# NOTE: Experimental, maybe incorporate as part of query call
proc queryWithAccounting*(ws: WakuStore, req: HistoryQuery): Future[WakuStoreResult[HistoryResponse]] {.async, gcsafe.} =
  let peerOpt = ws.peerManager.selectPeer(WakuStoreCodec)
  if peerOpt.isNone():
    error "no suitable remote peers"
    waku_store_errors.inc(labelValues = [peerNotFoundFailure])
    return err(peerNotFoundFailure)

  let res = await ws.query(req, peerOpt.get())
  if res.isErr():
    return err(res.error)

  let response = res.get()

  # Perform accounting operation. Assumes wakuSwap protocol is mounted
  ws.wakuSwap.debit(peerOpt.get().peerId, response.messages.len)

  return ok(response)
