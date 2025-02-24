{.used.}

import
  std/[options, tables, sets],
  testutils/unittests, chronos, chronicles,
  stew/shims/net as stewNet,
  libp2p/switch,
  libp2p/protobuf/minprotobuf,
  libp2p/protocols/ping,
  libp2p/stream/[bufferstream, connection],
  libp2p/crypto/crypto,
  libp2p/multistream,
  ../../waku/v2/node/wakunode2,
  ../../waku/v2/utils/peers,
  ../test_helpers, ./utils

procSuite "Waku Keepalive":

  asyncTest "handle ping keepalives":
    let
      nodeKey1 = crypto.PrivateKey.random(Secp256k1, rng[])[]
      node1 = WakuNode.new(nodeKey1, ValidIpAddress.init("0.0.0.0"), Port(60000))
      nodeKey2 = crypto.PrivateKey.random(Secp256k1, rng[])[]
      node2 = WakuNode.new(nodeKey2, ValidIpAddress.init("0.0.0.0"), Port(60002))

    var completionFut = newFuture[bool]()

    proc pingHandler(peerId: PeerID) {.async, gcsafe, raises: [Defect].} =
      debug "Ping received"

      check:
        peerId == node1.switch.peerInfo.peerId

      completionFut.complete(true)

    await node1.start()
    await node1.mountRelay()
    await node1.mountLibp2pPing()

    await node2.start()
    await node2.mountRelay()
    
    let pingProto = Ping.new(handler = pingHandler)
    await pingProto.start()
    node2.switch.mount(pingProto)

    await node1.connectToNodes(@[node2.switch.peerInfo.toRemotePeerInfo()])

    node1.startKeepalive()

    check:
      (await completionFut.withTimeout(5.seconds)) == true

    await node2.stop()
    await node1.stop()
