## 2022-08-15 v0.11

Release highlights:
- Major improvements in the performance of historical message queries to longer-term, sqlite-only message stores.
- Introduction of an HTTP REST API with basic functionality
- On-chain RLN group management. This was also integrated into an [example spam-protected chat application](https://github.com/status-im/nwaku/blob/4f93510fc9a938954dd85593f8dc4135a1c367de/docs/tutorial/onchain-rln-relay-chat2.md).

The full list of changes is below.

### Features

- Support for on-chain group membership management in the [`17/WAKU-RLN-RELAY`](https://rfc.vac.dev/spec/17/) implementation.
- Integrated HTTP REST API for external access to some `wakunode2` functionality:
  - Debug REST API exposes debug information about a `wakunode2`.
  - Relay REST API allows basic pub/sub functionality according to [`11/WAKU2-RELAY`](https://rfc.vac.dev/spec/11/).
- [`35/WAKU2-NOISE`](https://rfc.vac.dev/spec/35/) implementation now adds padding to ChaChaPoly encryptions to increase security and reduce metadata leakage.

### Changes

- Significantly improved the SQLite-only historical message `store` query performance.
- Refactored several protocol implementations to improve maintainability and readability.
- Major code reorganization for the [`13/WAKU2-STORE`](https://rfc.vac.dev/spec/13/) implementation to improve maintainability. This will also make the `store` extensible to support multiple implementations.
- Disabled compiler log colors when running in a CI environment. 
- Refactored [`35/WAKU2-NOISE`](https://rfc.vac.dev/spec/35/) implementation into smaller submodules.
- [`11/WAKU2-RELAY`](https://rfc.vac.dev/spec/11/) implementation can now optionally be compiled with [Zerokit RLN](https://github.com/vacp2p/zerokit/tree/64f508363946b15ac6c52f8b59d8a739a33313ec/rln). Previously only [Kilic's RLN](https://github.com/kilic/rln/tree/7ac74183f8b69b399e3bc96c1ae8ab61c026dc43) was supported.

### Fixes

- Fixed wire encoding of protocol buffers to use proto3.
- Fixed Waku v1 <> Waku v2 bridge losing connection to statically configured v1 nodes.
- Fixed underlying issue causing DNS discovery to fail for records containing multiple strings.

### Docs

- Updated [release process](https://github.com/status-im/nwaku/blob/4f93510fc9a938954dd85593f8dc4135a1c367de/docs/contributors/release-process.md) documentation.
- Added [tutorial](https://github.com/status-im/nwaku/blob/4f93510fc9a938954dd85593f8dc4135a1c367de/docs/tutorial/onchain-rln-relay-chat2.md) on how to run a spam-protected chat2 application with on-chain group management.


This release supports the following [libp2p protocols](https://docs.libp2p.io/concepts/protocols/):
| Protocol | Spec status | Protocol id |
| ---: | :---: | :--- |
| [`11/WAKU2-RELAY`](https://rfc.vac.dev/spec/11/) | `stable` | `/vac/waku/relay/2.0.0` |
| [`12/WAKU2-FILTER`](https://rfc.vac.dev/spec/12/) | `draft` | `/vac/waku/filter/2.0.0-beta1` |
| [`13/WAKU2-STORE`](https://rfc.vac.dev/spec/13/) | `draft` | `/vac/waku/store/2.0.0-beta4` |
| [`18/WAKU2-SWAP`](https://rfc.vac.dev/spec/18/) | `draft` | `/vac/waku/swap/2.0.0-beta1` |
| [`19/WAKU2-LIGHTPUSH`](https://rfc.vac.dev/spec/19/) | `draft` | `/vac/waku/lightpush/2.0.0-beta1` |

The Waku v1 implementation is stable but not under active development.

## 2022-06-15 v0.10

Release highlights:
- Support for key exchange using Noise handshakes.
- Support for a SQLite-only historical message `store`. This allows for cheaper, longer-term historical message storage on disk rather than in memory.
- Several fixes for native WebSockets, including slow or hanging connections and connections dropping unexpectedly due to timeouts.
- A fix for a memory leak in nodes running a local SQLite database.

### Features

- Support for [`35/WAKU2-NOISE`](https://rfc.vac.dev/spec/35/) handshakes as key exchange protocols.
- Support for TOML config files via `--config-file=<path/to/config.toml>`.
- Support for `--version` command. This prints the current tagged version (or compiled commit hash, if not on a version).
- Support for running `store` protocol from a `filter` client, storing only the filtered messages.
- Start of an HTTP REST API implementation.
- Support for a memory-efficient SQLite-only `store` configuration.

### Changes

- Added index on `receiverTimestamp` in the SQLite `store` to improve query performance.
- GossipSub [Peer Exchange](https://github.com/libp2p/specs/blob/master/pubsub/gossipsub/gossipsub-v1.1.md#prune-backoff-and-peer-exchange) is now disabled by default. This is a more secure option.
- Progress towards dynamic group management for the [`17/WAKU-RLN-RELAY`](https://rfc.vac.dev/spec/17/) implementation.
- Nodes with `--keep-alive` enabled now sends more regular pings to keep connections more reliably alive.
- Disabled `swap` protocol by default.
- Reduced unnecessary and confusing logging, especially during startup.
- Added discv5 UDP port to the node's main discoverable ENR.

### Fixes

- The in-memory `store` now checks the validity of message timestamps before storing.
- Fixed underlying bug that caused connection leaks in the HTTP client.
- Fixed Docker image compilation to use the correct external variable for compile-time flags (`NIMFLAGS` instead of `NIM_PARAMS`).
- Fixed issue where `--dns4-domain-name` caused an unhandled exception if no external port was available.
- Avoids unnecessarily calling DB migration if a `--db-path` is set but nothing is persisted in the DB. This led to a misleading warning log.
- Fixed underlying issues that caused WebSocket connections to hang.
- Fixed underlying issue that caused WebSocket connections to time out after 10 mins.
- Fixed memory leak in nodes that implements a SQLite database.

### Docs

- Added [tutorial](https://github.com/status-im/nwaku/blob/16dd267bd9d25ff24c64fc5c92a20eb0d322217c/docs/operators/how-to/configure-key.md) on how to generate and configure a node key.
- Added first [guide](https://github.com/status-im/nwaku/tree/16dd267bd9d25ff24c64fc5c92a20eb0d322217c/docs/operators) for nwaku operators.

This release supports the following [libp2p protocols](https://docs.libp2p.io/concepts/protocols/):
| Protocol | Spec status | Protocol id |
| ---: | :---: | :--- |
| [`11/WAKU2-RELAY`](https://rfc.vac.dev/spec/11/) | `stable` | `/vac/waku/relay/2.0.0` |
| [`12/WAKU2-FILTER`](https://rfc.vac.dev/spec/12/) | `draft` | `/vac/waku/filter/2.0.0-beta1` |
| [`13/WAKU2-STORE`](https://rfc.vac.dev/spec/13/) | `draft` | `/vac/waku/store/2.0.0-beta4` |
| [`18/WAKU2-SWAP`](https://rfc.vac.dev/spec/18/) | `draft` | `/vac/waku/swap/2.0.0-beta1` |
| [`19/WAKU2-LIGHTPUSH`](https://rfc.vac.dev/spec/19/) | `draft` | `/vac/waku/lightpush/2.0.0-beta1` |

The Waku v1 implementation is stable but not under active development.

## 2022-03-31 v0.9

Release highlights:

- Support for Peer Exchange (PX) when a peer prunes a [`11/WAKU2-RELAY`](https://rfc.vac.dev/spec/11/) mesh due to oversubscription. This can significantly increase mesh stability.
- Improved start-up times through managing the size of the underlying persistent message storage.
- New websocket connections are no longer blocked due to parsing failures in other connections.

The full list of changes is below.

### Features

- Support for bootstrapping [`33/WAKU-DISCV5`](https://rfc.vac.dev/spec/33) via [DNS discovery](https://rfc.vac.dev/spec/10/#discovery-methods)
- Support for GossipSub [Peer Exchange](https://github.com/libp2p/specs/blob/master/pubsub/gossipsub/gossipsub-v1.1.md#prune-backoff-and-peer-exchange)

### Changes

- Waku v1 <> v2 bridge now supports DNS `multiaddrs`
- Waku v1 <> v2 bridge now validates content topics before attempting to bridge a message from Waku v2 to Waku v1
- Persistent message storage now auto deletes messages once over specified `--store-capacity`. This can significantly improve node start-up times.
- Renamed Waku v1 <> v2 bridge `make` target and binary to `wakubridge`
- Increased `store` logging to assist with debugging
- Increased `rln-relay` logging to assist with debugging
- Message metrics no longer include the content topic as a dimension to keep Prometheus metric cardinality under control
- Waku v2 `toy-chat` application now sets the sender timestamp when creating messages
- The type of the `proof` field of the `WakuMessage` is changed to `RateLimitProof`
- Added method to the JSON-RPC API that returns the git tag and commit hash of the binary
- The node's ENR is now included in the JSON-RPC API response when requesting node info

### Fixes

- Fixed incorrect conversion of seconds to nanosecond timestamps
- Fixed store queries blocking due to failure in resource clean up
- Fixed underlying issue where new websocket connections are blocked due to parsing failures in other connections
- Fixed failure to log the ENR necessary for a discv5 connection to the node

### Docs

- Added [RAM requirements](https://github.com/status-im/nim-waku/tree/ee96705c7fbe4063b780ac43b7edee2f6c4e351b/waku/v2#wakunode) to `wakunode2` build instructions
- Added [tutorial](https://github.com/status-im/nim-waku/blob/ee96705c7fbe4063b780ac43b7edee2f6c4e351b/docs/tutorial/rln-chat2-live-testnet.md) on communicating with waku2 test fleets via the chat2 `toy-chat` application in spam-protected mode using [`17/WAKU-RLN-RELAY`](https://rfc.vac.dev/spec/17/).
- Added a [section on bug reporting](https://github.com/status-im/nim-waku/blob/ee96705c7fbe4063b780ac43b7edee2f6c4e351b/README.md#bugs-questions--features) to `wakunode2` README
- Fixed broken links in the [JSON-RPC API Tutorial](https://github.com/status-im/nim-waku/blob/5ceef37e15a15c52cbc589f0b366018e81a958ef/docs/tutorial/jsonrpc-api.md)

This release supports the following [libp2p protocols](https://docs.libp2p.io/concepts/protocols/):
| Protocol | Spec status | Protocol id |
| ---: | :---: | :--- |
| [`11/WAKU2-RELAY`](https://rfc.vac.dev/spec/11/) | `stable` | `/vac/waku/relay/2.0.0` |
| [`12/WAKU2-FILTER`](https://rfc.vac.dev/spec/12/) | `draft` | `/vac/waku/filter/2.0.0-beta1` |
| [`13/WAKU2-STORE`](https://rfc.vac.dev/spec/13/) | `draft` | `/vac/waku/store/2.0.0-beta4` |
| [`18/WAKU2-SWAP`](https://rfc.vac.dev/spec/18/) | `draft` | `/vac/waku/swap/2.0.0-beta1` |
| [`19/WAKU2-LIGHTPUSH`](https://rfc.vac.dev/spec/19/) | `draft` | `/vac/waku/lightpush/2.0.0-beta1` |

The Waku v1 implementation is stable but not under active development.

##  2022-03-03 v0.8

Release highlights:

- Working demonstration and integration of [`17/WAKU-RLN-RELAY`](https://rfc.vac.dev/spec/17/) in the Waku v2 `toy-chat` application
- Beta support for ambient peer discovery using [a version of Discovery v5](https://github.com/vacp2p/rfc/pull/487)
- A fix for the issue that caused a `store` node to run out of memory after serving a number of historical queries
- Ability to configure a `dns4` domain name for a node and resolve other dns-based `multiaddrs`

The full list of changes is below.

### Features

- [`17/WAKU-RLN-RELAY`](https://rfc.vac.dev/spec/17/) implementation now supports spam-protection for a specific combination of `pubsubTopic` and `contentTopic` (available under the `rln` compiler flag).  
- [`17/WAKU-RLN-RELAY`](https://rfc.vac.dev/spec/17/) integrated into chat2 `toy-chat` (available under the `rln` compiler flag)
- Added support for resolving dns-based `multiaddrs`
- A Waku v2 node can now be configured with a domain name and `dns4` `multiaddr`
- Support for ambient peer discovery using [`33/WAKU-DISCV5`](https://github.com/vacp2p/rfc/pull/487)

### Changes

- Metrics: now monitoring content topics and the sources of new connections
- Metrics: improved default fleet monitoring dashboard
- Introduced a `Timestamp` type (currently an alias for int64).
- All timestamps changed to nanosecond resolution.
- `timestamp` field number in WakuMessage object changed from `4` to `10`
- [`13/WAKU2-STORE`](https://rfc.vac.dev/spec/13/) identifier updated to `/vac/waku/store/2.0.0-beta4`
- `toy-chat` application now uses DNS discovery to connect to existing fleets

### Fixes

- Fixed underlying bug that caused occasional failures when reading the certificate for secure websockets
- Fixed `store` memory usage issues when responding to history queries

### Docs

- Documented [use of domain certificates](https://github.com/status-im/nim-waku/tree/2972a5003568848164033da3fe0d7f52a3d54824/waku/v2#enabling-websocket) for secure websockets
- Documented [how to configure a `dns4` domain name](https://github.com/status-im/nim-waku/tree/2972a5003568848164033da3fe0d7f52a3d54824/waku/v2#using-dns-discovery-to-connect-to-existing-nodes) for a node
- Clarified [use of DNS discovery](https://github.com/status-im/nim-waku/tree/2972a5003568848164033da3fe0d7f52a3d54824/waku/v2#using-dns-discovery-to-connect-to-existing-nodes) and provided current URLs for discoverable fleet nodes
- Added [tutorial](https://github.com/status-im/nim-waku/blob/2972a5003568848164033da3fe0d7f52a3d54824/docs/tutorial/rln-chat2-local-test.md) on using [`17/WAKU-RLN-RELAY`](https://rfc.vac.dev/spec/17/) with the chat2 `toy-chat` application
- Added [tutorial](https://github.com/status-im/nim-waku/blob/2972a5003568848164033da3fe0d7f52a3d54824/docs/tutorial/bridge.md) on how to configure and a use a [`15/WAKU-BRIDGE`](https://rfc.vac.dev/spec/15/)

This release supports the following [libp2p protocols](https://docs.libp2p.io/concepts/protocols/):
| Protocol | Spec status | Protocol id |
| ---: | :---: | :--- |
| [`11/WAKU2-RELAY`](https://rfc.vac.dev/spec/11/) | `stable` | `/vac/waku/relay/2.0.0` |
| [`12/WAKU2-FILTER`](https://rfc.vac.dev/spec/12/) | `draft` | `/vac/waku/filter/2.0.0-beta1` |
| [`13/WAKU2-STORE`](https://rfc.vac.dev/spec/13/) | `draft` | `/vac/waku/store/2.0.0-beta4` |
| [`18/WAKU2-SWAP`](https://rfc.vac.dev/spec/18/) | `draft` | `/vac/waku/swap/2.0.0-beta1` |
| [`19/WAKU2-LIGHTPUSH`](https://rfc.vac.dev/spec/19/) | `draft` | `/vac/waku/lightpush/2.0.0-beta1` |

The Waku v1 implementation is stable but not under active development.

##  2022-01-19 v0.7

Release highlights:

- Support for secure websockets.
- Ability to remove unreachable clients in a `filter` node.
- Several fixes to improve `store` performance and decrease query times. Query time for large stores decreased from longer than 8 min to under 100 ms.
- Fix for a long-standing bug that prevented proper database migration in some deployed Docker containers.

The full list of changes is below.

### Features

- Support for secure websocket transport

### Changes

- Filter nodes can now remove unreachable clients
- The WakuInfo `listenStr` is deprecated and replaced with a sequence of `listenAddresses` to accommodate multiple transports
- Removed cached `peerInfo` on local node. Rely on underlying libp2p switch instead
- Metrics: added counters for protocol messages
- Waku v2 node discovery now supports [`31/WAKU2-ENR`](https://rfc.vac.dev/spec/31/)
- resuming the history via `resume` now takes the answers of all peers in `peerList` into consideration and consolidates them into one deduplicated list

### Fixes

- Fixed database migration failure in the Docker image
- All `HistoryResponse` messages are now auto-paginated to a maximum of 100 messages per response
- Increased maximum length for reading from a libp2p input stream to allow largest possible protocol messages, including `HistoryResponse` messages at max size
- Significantly improved `store` node query performance
- Implemented a GossipSub `MessageIdProvider` for `11/WAKU2-RELAY` messages instead of relying on the unstable default
- Receiver timestamps for message indexing in the `store` now have consistent millisecond resolution

This release supports the following [libp2p protocols](https://docs.libp2p.io/concepts/protocols/):
| Protocol | Spec status | Protocol id |
| ---: | :---: | :--- |
| [`17/WAKU-RLN-RELAY`](https://rfc.vac.dev/spec/17/) | `raw` | `/vac/waku/waku-rln-relay/2.0.0-alpha1` |
| [`11/WAKU2-RELAY`](https://rfc.vac.dev/spec/11/) | `stable` | `/vac/waku/relay/2.0.0` |
| [`12/WAKU2-FILTER`](https://rfc.vac.dev/spec/12/) | `draft` | `/vac/waku/filter/2.0.0-beta1` |
| [`13/WAKU2-STORE`](https://rfc.vac.dev/spec/13/) | `draft` | `/vac/waku/store/2.0.0-beta3` |
| [`18/WAKU2-SWAP`](https://rfc.vac.dev/spec/18/) | `draft` | `/vac/waku/swap/2.0.0-beta1` |
| [`19/WAKU2-LIGHTPUSH`](https://rfc.vac.dev/spec/19/) | `draft` | `/vac/waku/lightpush/2.0.0-beta1` |

The Waku v1 implementation is stable but not under active development.

## 2021-11-05 v0.6

Some useful features and fixes in this release, include:
- two methods for Waku v2 node discovery
- support for unsecure websockets, which paves the way for native browser usage
- a fix for `nim-waku` store nodes running out of memory due to store size: the number of stored messages can now easily be configured
- a fix for densely connected nodes refusing new connections: the maximum number of allowed connections can now easily be configured
- support for larger message sizes (up from 64kb to 1Mb per message)

The full list of changes is below.

### Features

- Waku v2 node discovery via DNS following [EIP-1459](https://eips.ethereum.org/EIPS/eip-1459)
- Waku v2 node discovery via [Node Discovery v5](https://github.com/ethereum/devp2p/blob/master/discv5/discv5-theory.md)

### Changes

- Pagination of historical queries are now simplified
- GossipSub [prune backoff period](https://github.com/libp2p/specs/blob/master/pubsub/gossipsub/gossipsub-v1.1.md#prune-backoff-and-peer-exchange) is now the recommended 1 minute
- Bridge now uses content topic format according to [23/WAKU2-TOPICS](https://rfc.vac.dev/spec/23/)
- Better internal differentiation between local and remote peer info
- Maximum number of libp2p connections is now configurable
- `udp-port` CLI option has been removed for binaries where it's not used
- Waku v2 now supports unsecure WebSockets
- Waku v2 now supports larger message sizes of up to 1 Mb by default
- Further experimental development of [RLN for spam protection](https://rfc.vac.dev/spec/17/).
These changes are disabled by default under a compiler flag. Changes include:
  - Per-message rate limit proof defined
  - RLN proof generation and verification integrated into Waku v2
  - RLN tree depth changed from 32 to 20
  - Support added for static membership group formation

#### Docs

- Added [contributor guidelines](https://github.com/status-im/nim-waku/blob/master/docs/contributors/waku-fleets.md) on Waku v2 fleet monitoring and management
- Added [basic tutorial](https://github.com/status-im/nim-waku/blob/master/docs/tutorial/dns-disc.md) on using Waku v2 DNS-based discovery

### Fixes

- Bridge between `toy-chat` and matterbridge now shows correct announced addresses
- Bridge no longer re-encodes already encoded payloads when publishing to V1
- Bridge now populates WakuMessage timestamps when publishing to V2
- Store now has a configurable maximum number of stored messages
- Network simulations for Waku v1 and Waku v2 are runnable again

This release supports the following [libp2p protocols](https://docs.libp2p.io/concepts/protocols/):
| Protocol | Spec status | Protocol id |
| ---: | :---: | :--- |
| [`17/WAKU-RLN`](https://rfc.vac.dev/spec/17/) | `raw` | `/vac/waku/waku-rln-relay/2.0.0-alpha1` |
| [`11/WAKU2-RELAY`](https://rfc.vac.dev/spec/11/) | `stable` | `/vac/waku/relay/2.0.0` |
| [`12/WAKU2-FILTER`](https://rfc.vac.dev/spec/12/) | `draft` | `/vac/waku/filter/2.0.0-beta1` |
| [`13/WAKU2-STORE`](https://rfc.vac.dev/spec/13/) | `draft` | `/vac/waku/store/2.0.0-beta3` |
| [`18/WAKU2-SWAP`](https://rfc.vac.dev/spec/18/) | `draft` | `/vac/waku/swap/2.0.0-beta1` |
| [`19/WAKU2-LIGHTPUSH`](https://rfc.vac.dev/spec/19/) | `draft` | `/vac/waku/lightpush/2.0.0-beta1` |

The Waku v1 implementation is stable but not under active development.

## 2021-07-26 v0.5.1

This patch release contains the following fix:
- Support for multiple protocol IDs when reconnecting to previously connected peers:
A bug in `v0.5` caused clients using persistent peer storage to only support the mounted protocol ID.

This is a patch release that is fully backwards-compatible with release `v0.5`.
It supports the same [libp2p protocols](https://docs.libp2p.io/concepts/protocols/):
| Protocol | Spec status | Protocol id |
| ---: | :---: | :--- |
| [`17/WAKU-RLN`](https://rfc.vac.dev/spec/17/) | `raw` | `/vac/waku/waku-rln-relay/2.0.0-alpha1` |
| [`11/WAKU2-RELAY`](https://rfc.vac.dev/spec/11/) | `stable` | `/vac/waku/relay/2.0.0` |
| [`12/WAKU2-FILTER`](https://rfc.vac.dev/spec/12/) | `draft` | `/vac/waku/filter/2.0.0-beta1` |
| [`13/WAKU2-STORE`](https://rfc.vac.dev/spec/13/) | `draft` | `/vac/waku/store/2.0.0-beta3` |
| [`18/WAKU2-SWAP`](https://rfc.vac.dev/spec/18/) | `draft` | `/vac/waku/swap/2.0.0-beta1` |
| [`19/WAKU2-LIGHTPUSH`](https://rfc.vac.dev/spec/19/) | `draft` | `/vac/waku/lightpush/2.0.0-beta1` |

The Waku v1 implementation is stable but not under active development.

## 2021-07-23 v0.5

This release contains the following:

### Features
- Support for keep-alives using [libp2p ping protocol](https://docs.libp2p.io/concepts/protocols/#ping).
- DB migration for the message and peer stores.
- Support for multiple protocol IDs. Mounted protocols now match versions of the same protocol that adds a postfix to the stable protocol ID.

### Changes
- Bridge topics are now configurable.
- The `resume` Nim API now eliminates duplicates messages before storing them.
- The `resume` Nim API now fetches historical messages in page sequence.
- Added support for stable version of `relay` protocol, with protocol ID `/vac/waku/relay/2.0.0`.
- Added optional `timestamp` to `WakuRelayMessage`.
- Removed `PCRE` as a prerequisite for building Waku v1 and Waku v2.
- Improved [`swap`](https://rfc.vac.dev/spec/18/) metrics.

#### General refactoring
- Refactored modules according to [Nim best practices](https://hackmd.io/1imOGULZRsed2HpgmzGleA).
- Simplified the [way protocols get notified](https://github.com/status-im/nim-waku/issues/574) of new messages.
- Refactored `wakunode2` setup into 6 distinct phases with improved logging and error handling.
- Moved `Whisper` types and protocol from the `nim-eth` module to `nim-waku`.

#### Docs
- Added [database migration tutorial](https://github.com/status-im/nim-waku/blob/master/docs/tutorial/db-migration.md).
- Added [tutorial to setup `websockify`](https://github.com/status-im/nim-waku/blob/master/docs/tutorial/websocket.md).

#### Schema
- Updated the `Message` table of the persistent message store:
  - Added `senderTimestamp` column.
  - Renamed the `timestamp` column to `receiverTimestamp` and changes its type to `REAL`.

#### API
- Added optional `timestamp` to [`WakuRelayMessage`](https://rfc.vac.dev/spec/16/#wakurelaymessage) on JSON-RPC API.

### Fixes
- Conversion between topics for the Waku v1 <-> v2 bridge now follows the [RFC recommendation](https://rfc.vac.dev/spec/23/).
- Fixed field order of `HistoryResponse` protobuf message: the field numbers of the `HistoryResponse` are shifted up by one to match up the [13/WAKU2-STORE](https://rfc.vac.dev/spec/13/) specs.

This release supports the following [libp2p protocols](https://docs.libp2p.io/concepts/protocols/):
| Protocol | Spec status | Protocol id |
| ---: | :---: | :--- |
| [`17/WAKU-RLN`](https://rfc.vac.dev/spec/17/) | `raw` | `/vac/waku/waku-rln-relay/2.0.0-alpha1` |
| [`11/WAKU2-RELAY`](https://rfc.vac.dev/spec/11/) | `stable` | `/vac/waku/relay/2.0.0` |
| [`12/WAKU2-FILTER`](https://rfc.vac.dev/spec/12/) | `draft` | `/vac/waku/filter/2.0.0-beta1` |
| [`13/WAKU2-STORE`](https://rfc.vac.dev/spec/13/) | `draft` | `/vac/waku/store/2.0.0-beta3` |
| [`18/WAKU2-SWAP`](https://rfc.vac.dev/spec/18/) | `draft` | `/vac/waku/swap/2.0.0-beta1` |
| [`19/WAKU2-LIGHTPUSH`](https://rfc.vac.dev/spec/19/) | `draft` | `/vac/waku/lightpush/2.0.0-beta1` |

The Waku v1 implementation is stable but not under active development.

## 2021-06-03 v0.4

This release contains the following:

### Features

- Initial [`toy-chat` implementation](https://rfc.vac.dev/spec/22/)

### Changes

- The [toy-chat application](https://github.com/status-im/nim-waku/blob/master/docs/tutorial/chat2.md) can now perform `lightpush` and request content-filtered messages from remote peers.
- The [toy-chat application](https://github.com/status-im/nim-waku/blob/master/docs/tutorial/chat2.md) now uses default content topic `/toy-chat/2/huilong/proto`
- Improve `toy-chat` [briding to matterbridge]((https://github.com/status-im/nim-waku/blob/master/docs/tutorial/chat2.md#bridge-messages-between-chat2-and-matterbridge))
- Improve [`swap`](https://rfc.vac.dev/spec/18/) logging and enable soft mode by default
- Content topics are no longer in a redundant nested structure
- Improve error handling

#### API

- [JSON-RPC Store API](https://rfc.vac.dev/spec/16): Added an optional time-based query to filter historical messages.
- [Nim API](https://github.com/status-im/nim-waku/blob/master/docs/api/v2/node.md): Added `resume` method.

### Fixes

- Connections between nodes no longer become unstable due to keep-alive errors if mesh grows large
- Re-enable `lightpush` tests and fix Windows CI failure

The [Waku v2 suite of protocols](https://rfc.vac.dev/) are still in a raw/draft state.
This release supports the following [libp2p protocols](https://docs.libp2p.io/concepts/protocols/):
| Protocol | Spec status | Protocol id |
| ---: | :---: | :--- |
| [`17/WAKU-RLN`](https://rfc.vac.dev/spec/17/) | `raw` | `/vac/waku/waku-rln-relay/2.0.0-alpha1` |
| [`11/WAKU2-RELAY`](https://rfc.vac.dev/spec/11/) | `draft` | `/vac/waku/relay/2.0.0-beta2` |
| [`12/WAKU2-FILTER`](https://rfc.vac.dev/spec/12/) | `draft` | `/vac/waku/filter/2.0.0-beta1` |
| [`13/WAKU2-STORE`](https://rfc.vac.dev/spec/13/) | `draft` | `/vac/waku/store/2.0.0-beta3` |
| [`18/WAKU2-SWAP`](https://rfc.vac.dev/spec/18/) | `draft` | `/vac/waku/swap/2.0.0-beta1` |
| [`19/WAKU2-LIGHTPUSH`](https://rfc.vac.dev/spec/19/) | `draft` | `/vac/waku/lightpush/2.0.0-beta1` |

The Waku v1 implementation is stable but not under active development.

## 2021-05-11 v0.3

This release contains the following:

### Features

- Start of [`RLN relay` implementation](https://rfc.vac.dev/spec/17/)
- Start of [`swap` implementation](https://rfc.vac.dev/spec/18/)
- Start of [fault-tolerant `store` implementation](https://rfc.vac.dev/spec/21/)
- Initial [`bridge` implementation](https://rfc.vac.dev/spec/15/) between Waku v1 and v2 protocols
- Initial [`lightpush` implementation](https://rfc.vac.dev/spec/19/)
- A peer manager for `relay`, `filter`, `store` and `swap` peers
- Persistent storage for peers: A node with this feature enabled will now attempt to reconnect to `relay` peers after a restart. It will respect the gossipsub [PRUNE backoff](https://github.com/libp2p/specs/blob/master/pubsub/gossipsub/gossipsub-v1.1.md#prune-backoff-and-peer-exchange) period before attempting to do so.
- `--persist-peers` CLI option to persist peers in local storage
- `--persist-messages` CLI option to store historical messages locally
- `--keep-alive` CLI option to maintain a stable connection to `relay` peers on idle topics
- A CLI chat application ([`chat2`](https://github.com/status-im/nim-waku/blob/master/docs/tutorial/chat2.md)) over Waku v2 with [bridging to matterbridge](https://github.com/status-im/nim-waku/blob/master/docs/tutorial/chat2.md#bridge-messages-between-chat2-and-matterbridge)

### Changes
- Enable `swap` protocol by default and improve logging
#### General refactoring

- Split out `waku_types` types into the right place; create `utils` folder.
- Change type of `contentTopic` in [`ContentFilter`](https://rfc.vac.dev/spec/12/#protobuf) to `string`.
- Replace sequence of `contentTopics` in [`ContentFilter`](https://rfc.vac.dev/spec/12/#protobuf) with a single `contentTopic`.
- Add `timestamp` field to [`WakuMessage`](https://rfc.vac.dev/spec/14/#payloads).
- Ensure CLI config parameters use a consistent naming scheme. Summary of changes [here](https://github.com/status-im/nim-waku/pull/543).

#### Docs

Several clarifications and additions aimed at contributors, including
  - information on [how to query Status test fleet](https://github.com/status-im/nim-waku/blob/master/docs/faq.md) for node addresses,
  - [how to view logs](https://github.com/status-im/nim-waku/blob/master/docs/contributors/cluster-logs.md), and
  - [how to update submodules](https://github.com/status-im/nim-waku/blob/master/docs/contributors/git-submodules.md).

#### Schema

- Add `Message` table to the persistent message store. This table replaces the old `messages` table. It has two additional columns, namely
  - `pubsubTopic`, and
  - `version`.
- Add `Peer` table for persistent peer storage.

#### API

- [JSON-RPC Admin API](https://rfc.vac.dev/spec/16): Added a [`post` method](https://rfc.vac.dev/spec/16/#post_waku_v2_admin_v1_peers) to connect to peers on an ad-hoc basis.
- [Nim API](https://github.com/status-im/nim-waku/blob/master/docs/api/v2/node.md): PubSub topic `subscribe` and `unsubscribe` no longer returns a future (removed `async` designation).
- [`HistoryQuery`](https://rfc.vac.dev/spec/13/#historyquery): Added  `pubsubTopic` field. Message history can now be filtered and queried based on the `pubsubTopic`.
- [`HistoryQuery`](https://rfc.vac.dev/spec/13/#historyquery): Added support for querying a time window by specifying start and end times.

### Fixes

- Running nodes can now be shut down gracefully
- Content filtering now works on any PubSub topic and not just the `waku` default.
- Nodes can now mount protocols without supporting `relay` as a capability

The [Waku v2 suite of protocols](https://rfc.vac.dev/) are still in a raw/draft state.
This release supports the following [libp2p protocols](https://docs.libp2p.io/concepts/protocols/):
| Protocol | Spec status | Protocol id |
| ---: | :---: | :--- |
| [`17/WAKU-RLN`](https://rfc.vac.dev/spec/17/) | `raw` | `/vac/waku/waku-rln-relay/2.0.0-alpha1` |
| [`18/WAKU2-SWAP`](https://rfc.vac.dev/spec/18/) | `raw` | `/vac/waku/swap/2.0.0-alpha1` |
| [`19/WAKU2-LIGHTPUSH`](https://rfc.vac.dev/spec/19/) | `raw` | `/vac/waku/lightpush/2.0.0-alpha1` |
| [`11/WAKU2-RELAY`](https://rfc.vac.dev/spec/11/) | `draft` | `/vac/waku/relay/2.0.0-beta2` |
| [`12/WAKU2-FILTER`](https://rfc.vac.dev/spec/12/) | `draft` | `/vac/waku/filter/2.0.0-beta1` |
| [`13/WAKU2-STORE`](https://rfc.vac.dev/spec/13/) | `draft` | `/vac/waku/store/2.0.0-beta3` |

The Waku v1 implementation is stable but not under active development.

## 2021-01-05 v0.2

This release contains the following changes:

- Calls to `publish` a message on `wakunode2` now `await` instead of `discard` dispatched [`WakuRelay`](https://github.com/vacp2p/specs/blob/master/specs/waku/v2/waku-relay.md) procedures.
- [`StrictNoSign`](https://github.com/libp2p/specs/tree/master/pubsub#message-signing) enabled.
- Add JSON-RPC API for external access to `wakunode2` functionality:
  - Admin API retrieves information about peers registered on the `wakunode2`.
  - Debug API exposes debug information about a `wakunode2`.
  - Filter API saves bandwidth by allowing light nodes to filter for specific content.
  - Private API enables symmetric or asymmetric cryptography to encrypt/decrypt message payloads.
  - Relay API allows basic pub/sub functionality.
  - Store API retrieves historical messages.
- Add tutorial on how to use JSON-RPC API.
- Refactor: Move `waku_filter` protocol into its own module.

The Waku v2 implementation, and [most protocols it consist of](https://specs.vac.dev/specs/waku/),
are still in a draft/beta state. The Waku v1 implementation is stable but not under active development.

## 2020-11-30 v0.1

Initial beta release.

This release contains:

- A Nim implementation of the [Waku v1 protocol](https://specs.vac.dev/waku/waku.html).
- A Nim implementation of the [Waku v2 protocol](https://specs.vac.dev/specs/waku/v2/waku-v2.html).
- CLI applications `wakunode` and `wakunode2` that allows you to run a Waku v1 or v2 node.
- Examples of Waku v1 and v2 usage.
- Various tests of above.

Currenty the Waku v2 implementation, and [most protocols it consist of](https://specs.vac.dev/specs/waku/),
are in a draft/beta state. The Waku v1 implementation is stable but not under active development.

Feedback welcome!
