import
  strformat, os, osproc, net, strformat, chronicles, confutils, json,
  eth/p2p/discoveryv5/enr,
  eth/keys,
  stew/shims/net as stewNet,
  libp2p/multiaddress,
  libp2p/crypto/crypto,
  libp2p/crypto/secp,
  libp2p/peerinfo

# Fix ambiguous call error
import strutils except fromHex

const
  # Scenarios without discv5
  # defaults ="--log-level:TRACE --metrics-logging --metrics-server --rpc"
  # # Scenarios using discv5
  defaults ="--log-level:TRACE --metrics-logging --metrics-server --rpc --discv5-discovery --discv5-table-ip-limit=1024 --discv5-bucket-ip-limit=16 --discv5-bits-per-hop=1"
  wakuNodeBin = "build" / "wakunode2"
  metricsDir = "metrics"
  portOffset = 2
  discv5ExtIpAddr = "127.0.0.1" # Scenarios using discv5

type
  NodeInfo* = object
    cmd: string
    master: bool
    address: string
    shift: int
    label: string
    enrUri: string # Scenarios using discv5

  Topology = enum
    Star,
    FullMesh,
    BootstrapFleet # comprising one full-mesh core (fleet) and satellites (full nodes) using the fleet as bootstrap nodes
   
  WakuNetworkConf* = object
    topology* {.
      desc: "Set the network topology."
      defaultValue: FullMesh
      name: "topology" .}: Topology

    amount* {.
      desc: "Amount of relay nodes to be started."
      defaultValue: 16
      name: "amount" .}: int

    numFleetNodes* {.
      desc: "Number of Fleetnodes."
      defaultValue: 3
      name: "numFleetNodes" .}: int


proc debugPrintEnrURI(enrUri: string) =
  var r: Record
  if not fromURI(r, enrUri):
    echo "could not read ENR URI"
  echo "ENR content: ",  r

# NOTE: Don't distinguish between node types here a la full node, light node etc
proc initNodeCmd(shift: int, staticNodes: seq[string] = @[], master = false, label: string, discv5BootStrapEnrs: seq[string] = @[]): NodeInfo =
  let
    rng = crypto.newRng()
    key = SkPrivateKey.random(rng[])
    hkey = key.getBytes().toHex()
    rkey = SkPrivateKey.init(fromHex(hkey))[] #assumes ok
    privKey = crypto.PrivateKey(scheme: Secp256k1, skkey: rkey)
    #privKey = PrivateKey.random(Secp256k1)
    pubkey = privKey.getPublicKey()[] #assumes ok
    keyPair = crypto.KeyPair(seckey: privKey, pubkey: pubkey)
    peerInfo = PeerInfo.new(privKey)
    port = 60000 + shift
    discv5Port = 9000 + shift
    #DefaultAddr = "/ip4/127.0.0.1/tcp/55505"
    address = "/ip4/127.0.0.1/tcp/" & $port
    hostAddress = MultiAddress.init(address).tryGet()

  info "Address", address
  # TODO: Need to port shift
  peerInfo.addrs.add(hostAddress)
  let id = $peerInfo.peerId

  info "PeerInfo", id = id, addrs = peerInfo.addrs
  let listenStr = $peerInfo.addrs[0] & "/p2p/" & id

  result.cmd = wakuNodeBin & " " & defaults & " "
  result.cmd &= "--nodekey:" & hkey & " "
  result.cmd &= "--ports-shift:" & $shift & " "
  if staticNodes.len > 0:
    for staticNode in staticNodes:
      result.cmd &= "--staticnode:" & staticNode & " "

  # Scenarios using discv5
  result.cmd &= "--nat:extip:" & discv5ExtIpAddr & " "
  if discv5BootStrapEnrs.len > 0:
    for enr in discv5BootStrapEnrs:
      result.cmd &= "--discv5-bootstrap-node:" & enr & " "

  result.shift = shift
  result.label = label
  result.master = master
  result.address = listenStr

  # Scenarios using discv5
  # We have to manually build the ENR which the node ran with the currently build node command will generate,
  # because we need to know it before the node starts in order to be able to provide it as bootstrap information.
  # Note: the ENR built here is not exactly the same as we don't integrate the waku2 key in this test scenario.
  let enr = enr.Record.init(1,
    keys.PrivateKey.fromHex(hkey).expect("could not convert priv key from hex"),
    some(stewNet.ValidIpAddress.init(discv5ExtIpAddr)),
    some(Port(discv5Port)), # tcp-port
    some(Port(discv5Port))) # udp-port
    .expect("Record within size limits")
  result.enrUri = "enr:" & enr.toBase64

  info "Node command created.", cmd=result.cmd, address = result.address


# # Scenarios without discv5
# proc starNetwork(amount: int): seq[NodeInfo] =
#   let masterNode = initNodeCmd(portOffset, master = true, label = "master node")
#   result.add(masterNode)
#   for i in 1..<amount:
#     result.add(initNodeCmd(portOffset + i, @[masterNode.address], label = "full node"))

# Scenarios using discv5
proc starNetwork(amount: int): seq[NodeInfo] =
  let masterNode = initNodeCmd(portOffset, master = true, label = "master node")
  let bootstrapEnrList = @[masterNode.enrUri]
  result.add(masterNode)
  for i in 1..<amount:
    result.add(initNodeCmd(portOffset + i, label = "full node", discv5BootStrapEnrs = bootstrapEnrList)) # no waku bootstrap nodes; get bootstrap waku nodes via discv5


# Scenarios using discv5
proc bootstrapFleetNetwork(amount: int, numFleetNodes: int): seq[NodeInfo] =
  debug "number of fleet nodes", numFleetNodes
  debug "number of satellite nodes", amount

  var bootstrapEnrList: seq[string] = @[]    # bootstrap for discv5
  var bootstrapNodeList: seq[string] = @[]   # bootstrap for waku relay

  for i in 0..<numFleetNodes:
    for fleetNode in result:
      bootstrapEnrList.add(fleetNode.enrUri)
      bootstrapNodeList.add(fleetNode.address)
    result.add(initNodeCmd(portOffset + i, staticNodes = bootstrapNodeList, label = "fleet node", discv5BootStrapEnrs = bootstrapEnrList))

  for i in 0..<amount:
    result.add(initNodeCmd(portOffset + numFleetNodes + i, label = "full node", discv5BootStrapEnrs = bootstrapEnrList)) # no waku bootstrap nodes; get bootstrap waku nodes via discv5


# Scenarios without discv5
proc fullMeshNetwork(amount: int): seq[NodeInfo] =
  debug "amount", amount
  for i in 0..<amount:
    var staticnodes: seq[string]
    for item in result:
      staticnodes.add(item.address)
    result.add(initNodeCmd(portOffset + i, staticnodes, label = "full node"))

proc generatePrometheusConfig(nodes: seq[NodeInfo], outputFile: string) =
  var config = """
  global:
    scrape_interval: 1s

  scrape_configs:
    - job_name: "wakusim"
      static_configs:"""
  var count = 0
  for node in nodes:
    let port = 8008 + node.shift
    config &= &"""

      - targets: ['127.0.0.1:{port}']
        labels:
          node: '{count}'"""
    count += 1

  var (path, file) = splitPath(outputFile)
  createDir(path)
  writeFile(outputFile, config)

proc proccessGrafanaDashboard(nodes: int, inputFile: string,
    outputFile: string) =
  # from https://github.com/status-im/nim-beacon-chain/blob/master/tests/simulation/process_dashboard.nim
  var
    inputData = parseFile(inputFile)
    panels = inputData["panels"].copy()
    numPanels = len(panels)
    gridHeight = 0
    outputData = inputData

  for panel in panels:
    if panel["gridPos"]["x"].getInt() == 0:
      gridHeight += panel["gridPos"]["h"].getInt()

  outputData["panels"] = %* []
  for nodeNum in 0 .. (nodes - 1):
    var
      nodePanels = panels.copy()
      panelIndex = 0
    for panel in nodePanels.mitems:
      panel["title"] = %* replace(panel["title"].getStr(), "#0", "#" & $nodeNum)
      panel["id"] = %* (panelIndex + (nodeNum * numPanels))
      panel["gridPos"]["y"] = %* (panel["gridPos"]["y"].getInt() + (nodeNum * gridHeight))
      var targets = panel["targets"]
      for target in targets.mitems:
        target["expr"] = %* replace(target["expr"].getStr(), "{node=\"0\"}", "{node=\"" & $nodeNum & "\"}")
      outputData["panels"].add(panel)
      panelIndex.inc()

  outputData["uid"] = %* (outputData["uid"].getStr() & "a")
  outputData["title"] = %* (outputData["title"].getStr() & " (all nodes)")
  writeFile(outputFile, pretty(outputData))




when isMainModule:
  let conf = WakuNetworkConf.load()

  # TODO: WakuNetworkConf
  var nodes: seq[NodeInfo]
  let topology = conf.topology

  # Scenario xx2 14
  let amount = conf.amount
  let numFleetNodes = conf.numFleetNodes

  case topology:
    of Star:
      nodes = starNetwork(amount)
    of FullMesh:
      nodes = fullMeshNetwork(amount)
    of BootstrapFleet:
      nodes = bootstrapFleetNetwork(amount, numFleetNodes)

  # var staticnodes: seq[string]
  # for i in 0..<amount:
  #   # TODO: could also select nodes randomly
  #   staticnodes.add(nodes[i].address)

  # Scenario xx1 - 16 full nodes, one app topic, full mesh, gossip

  # Scenario xx2 - 14 full nodes, two edge nodes, one app topic, full mesh, gossip
  # NOTE: Only connecting to one node here
  #var nodesubseta: seq[string]
  #var nodesubsetb: seq[string]
  #nodesubseta.add(staticnodes[0])
  #nodesubsetb.add(staticnodes[amount-1])
  ## XXX: Let's turn them into normal nodes
  #nodes.add(initNodeCmd(0, nodesubseta, label = "edge node (A)"))
  #nodes.add(initNodeCmd(1, nodesubsetb, label = "edge node (B)"))

  var commandStr = "multitail -s 2 -M 0 -x \"Waku Simulation\""
  var count = 0
  var sleepDuration = 0
  for node in nodes:
    if topology in {Star}: #DiscoveryBased
      sleepDuration = if node.master: 0
                      else: 1
    commandStr &= &" -cT ansi -t 'node #{count} {node.label}' -l 'sleep {sleepDuration}; {node.cmd}; echo [node execution completed]; while true; do sleep 100; done'"
    if topology == FullMesh:
      sleepDuration += 1
      count += 1


  generatePrometheusConfig(nodes, metricsDir / "prometheus" / "prometheus.yml")
  proccessGrafanaDashboard(nodes.len,
                            metricsDir / "waku-grafana-dashboard.json",
                            metricsDir / "waku-sim-all-nodes-grafana-dashboard.json")


  let errorCode = execCmd(commandStr)
  if errorCode != 0:
    error "launch command failed", command=commandStr
