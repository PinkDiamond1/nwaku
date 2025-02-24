{.push raises: [Defect].}

import
  std/[tables,sequtils],
  chronicles,
  json_rpc/rpcserver
import
  ../../protocol/waku_message,
  ../../protocol/waku_filter,
  ../wakunode2,
  ./jsonrpc_types

export jsonrpc_types

logScope:
  topics = "filter api"

const futTimeout* = 5.seconds # Max time to wait for futures
const maxCache* = 30 # Max number of messages cached per topic @TODO make this configurable

proc installFilterApiHandlers*(node: WakuNode, rpcsrv: RpcServer, messageCache: MessageCache) =
  
  proc filterHandler(msg: WakuMessage) {.gcsafe, closure, raises: [Defect].} =
    # Add message to current cache
    trace "WakuMessage received", msg=msg
    
    # Make a copy of msgs for this topic to modify
    var msgs = messageCache.getOrDefault(msg.contentTopic, @[])

    if msgs.len >= maxCache:
      # Message cache on this topic exceeds maximum. Delete oldest.
      # @TODO this may become a bottle neck if called as the norm rather than exception when adding messages. Performance profile needed.
      msgs.delete(0,0)
    msgs.add(msg)

    # Replace indexed entry with copy
    # @TODO max number of content topics could be limited in node
    messageCache[msg.contentTopic] = msgs

  ## Filter API version 1 definitions
  
  rpcsrv.rpc("get_waku_v2_filter_v1_messages") do(contentTopic: ContentTopic) -> seq[WakuMessage]:
    ## Returns all WakuMessages received on a content topic since the
    ## last time this method was called
    ## @TODO ability to specify a return message limit
    debug "get_waku_v2_filter_v1_messages", contentTopic=contentTopic

    if messageCache.hasKey(contentTopic):
      let msgs = messageCache[contentTopic]
      # Clear cache before next call
      messageCache[contentTopic] = @[]
      return msgs
    else:
      # Not subscribed to this content topic
      raise newException(ValueError, "Not subscribed to content topic: " & $contentTopic)
  
  rpcsrv.rpc("post_waku_v2_filter_v1_subscription") do(contentFilters: seq[ContentFilter], topic: Option[string]) -> bool:
    ## Subscribes a node to a list of content filters
    debug "post_waku_v2_filter_v1_subscription"

    # Construct a filter request
    # @TODO use default PubSub topic if undefined
    let fReq = if topic.isSome: FilterRequest(pubSubTopic: topic.get, contentFilters: contentFilters, subscribe: true) else: FilterRequest(contentFilters: contentFilters, subscribe: true)
    
    if (await node.subscribe(fReq, filterHandler).withTimeout(futTimeout)):
      # Successfully subscribed to all content filters
      
      for cTopic in contentFilters.mapIt(it.contentTopic):
        # Create message cache for each subscribed content topic
        messageCache[cTopic] = @[]
      
      return true
    else:
      # Failed to subscribe to one or more content filters
      raise newException(ValueError, "Failed to subscribe to contentFilters " & repr(fReq))

  rpcsrv.rpc("delete_waku_v2_filter_v1_subscription") do(contentFilters: seq[ContentFilter], topic: Option[string]) -> bool:
    ## Unsubscribes a node from a list of content filters
    debug "delete_waku_v2_filter_v1_subscription"

    # Construct a filter request
    # @TODO consider using default PubSub topic if undefined
    let fReq = if topic.isSome: FilterRequest(pubSubTopic: topic.get, contentFilters: contentFilters, subscribe: false) else: FilterRequest(contentFilters: contentFilters, subscribe: false)

    if (await node.unsubscribe(fReq).withTimeout(futTimeout)):
      # Successfully unsubscribed from all content filters

      for cTopic in contentFilters.mapIt(it.contentTopic):
        # Remove message cache for each unsubscribed content topic
        messageCache.del(cTopic)

      return true
    else:
      # Failed to unsubscribe from one or more content filters
      raise newException(ValueError, "Failed to unsubscribe from contentFilters " & repr(fReq))
