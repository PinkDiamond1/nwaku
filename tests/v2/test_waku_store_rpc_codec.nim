{.used.}

import
  std/[options, times],
  stew/byteutils,
  testutils/unittests, 
  chronos, 
  chronicles
import
  ../../waku/v2/protocol/waku_message,
  ../../waku/v2/protocol/waku_store,
  ../../waku/v2/utils/pagination,
  ../../waku/v2/utils/time

const 
  DefaultPubsubTopic = "/waku/2/default-waku/proto"
  DefaultContentTopic = ContentTopic("/waku/2/default-content/proto")


proc fakeWakuMessage(
  payload = "TEST-PAYLOAD",
  contentTopic = DefaultContentTopic, 
  ts = getNanosecondTime(epochTime())
): WakuMessage = 
  WakuMessage(
    payload: toBytes(payload),
    contentTopic: contentTopic,
    version: 1,
    timestamp: ts
  )


procSuite "Waku Store - RPC codec":
  
  test "Index protobuf codec":
    ## Given
    let index = Index.compute(fakeWakuMessage(), receivedTime=getNanosecondTime(epochTime()), pubsubTopic=DefaultPubsubTopic)

    ## When
    let encodedIndex = index.encode()
    let decodedIndexRes = Index.init(encodedIndex.buffer)

    ## Then
    check:
      decodedIndexRes.isOk()
    
    let decodedIndex = decodedIndexRes.tryGet()
    check:
      # The fields of decodedIndex must be the same as the original index
      decodedIndex == index

  test "Index protobuf codec - empty index":
    ## Given
    let emptyIndex = Index()
    
    let encodedIndex = emptyIndex.encode()
    let decodedIndexRes = Index.init(encodedIndex.buffer)

    ## Then
    check:
      decodedIndexRes.isOk()
    
    let decodedIndex = decodedIndexRes.tryGet()
    check:
      # Check the correctness of init and encode for an empty Index
      decodedIndex == emptyIndex

  test "PagingInfo protobuf codec":
    ## Given
    let
      index = Index.compute(fakeWakuMessage(), receivedTime=getNanosecondTime(epochTime()), pubsubTopic=DefaultPubsubTopic)
      pagingInfo = PagingInfo(pageSize: 1, cursor: index, direction: PagingDirection.FORWARD)
      
    ## When
    let pb = pagingInfo.encode()
    let decodedPagingInfo = PagingInfo.init(pb.buffer)

    ## Then
    check:
      decodedPagingInfo.isOk()

    check:
      # the fields of decodedPagingInfo must be the same as the original pagingInfo
      decodedPagingInfo.value == pagingInfo
      decodedPagingInfo.value.direction == pagingInfo.direction
  
  test "PagingInfo protobuf codec - empty paging info":
    ## Given
    let emptyPagingInfo = PagingInfo()
      
    ## When
    let epb = emptyPagingInfo.encode()
    let decodedEmptyPagingInfo = PagingInfo.init(epb.buffer)

    ## Then
    check:
      decodedEmptyPagingInfo.isOk()

    check:
      # check the correctness of init and encode for an empty PagingInfo
      decodedEmptyPagingInfo.value == emptyPagingInfo
  
  test "HistoryQuery protobuf codec":
    ## Given
    let
      index = Index.compute(fakeWakuMessage(), receivedTime=getNanosecondTime(epochTime()), pubsubTopic=DefaultPubsubTopic)
      pagingInfo = PagingInfo(pageSize: 1, cursor: index, direction: PagingDirection.BACKWARD)
      query = HistoryQuery(contentFilters: @[HistoryContentFilter(contentTopic: DefaultContentTopic), HistoryContentFilter(contentTopic: DefaultContentTopic)], pagingInfo: pagingInfo, startTime: Timestamp(10), endTime: Timestamp(11))
    
    ## When
    let pb = query.encode()
    let decodedQuery = HistoryQuery.init(pb.buffer)

    ## Then
    check:
      decodedQuery.isOk()

    check:
      # the fields of decoded query decodedQuery must be the same as the original query query
      decodedQuery.value == query

  test "HistoryQuery protobuf codec - empty history query":
    ## Given
    let emptyQuery = HistoryQuery()

    ## When
    let epb = emptyQuery.encode()
    let decodedEmptyQuery = HistoryQuery.init(epb.buffer)

    ## Then
    check:
      decodedEmptyQuery.isOk()

    check:
      # check the correctness of init and encode for an empty HistoryQuery
      decodedEmptyQuery.value == emptyQuery
  
  test "HistoryResponse protobuf codec":
    ## Given
    let
      message = fakeWakuMessage()
      index = Index.compute(message, receivedTime=getNanosecondTime(epochTime()), pubsubTopic=DefaultPubsubTopic)
      pagingInfo = PagingInfo(pageSize: 1, cursor: index, direction: PagingDirection.BACKWARD)
      res = HistoryResponse(messages: @[message], pagingInfo:pagingInfo, error: HistoryResponseError.INVALID_CURSOR)
    
    ## When
    let pb = res.encode()
    let decodedRes = HistoryResponse.init(pb.buffer)

    ## Then
    check:
      decodedRes.isOk()

    check:
      # the fields of decoded response decodedRes must be the same as the original response res
      decodedRes.value == res
    
  test "HistoryResponse protobuf codec - empty history response":
    ## Given
    let emptyRes = HistoryResponse()
    
    ## When
    let epb = emptyRes.encode()
    let decodedEmptyRes = HistoryResponse.init(epb.buffer)

    ## Then
    check:
      decodedEmptyRes.isOk()

    check:
      # check the correctness of init and encode for an empty HistoryResponse
      decodedEmptyRes.value == emptyRes