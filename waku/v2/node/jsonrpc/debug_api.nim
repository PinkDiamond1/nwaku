{.push raises: [Defect].}

import
  chronicles,
  json_rpc/rpcserver,
  ../wakunode2

logScope:
  topics = "debug api"

const 
  git_version {.strdefine.} = "n/a"

proc installDebugApiHandlers*(node: WakuNode, rpcsrv: RpcServer) =

  ## Debug API version 1 definitions

  rpcsrv.rpc("get_waku_v2_debug_v1_info") do() -> WakuInfo:
    ## Returns information about WakuNode
    debug "get_waku_v2_debug_v1_info"

    return node.info()

  rpcsrv.rpc("get_waku_v2_debug_v1_version") do() -> string:
    ## Returns information about WakuNode
    debug "get_waku_v2_debug_v1_version"

    return git_version

