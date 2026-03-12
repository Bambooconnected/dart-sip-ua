import '../transports/socket_interface.dart';
import '../transports/web_socket.dart';
import 'events.dart';

class EventSocketConnected extends EventType {
  EventSocketConnected({this.socket});
  SIPUASocketInterface? socket;
}

class EventSocketConnecting extends EventType {
  EventSocketConnecting({this.socket});
  SIPUASocketInterface? socket;
}

class EventSocketDisconnected extends EventType {
  EventSocketDisconnected({SIPUASocketInterface? socket, this.cause});
  SIPUASocketInterface? socket;
  ErrorCause? cause;
}

/// Emitted whenever the UA receives an incoming SIP request over the
/// transport (before any routing / drop logic). Useful for diagnostics —
/// proves the message reached the app from the network.
class EventSipRequestReceived extends EventType {
  EventSipRequestReceived({this.method, this.from, this.callId});
  String? method;
  String? from;
  String? callId;
}

/// Emitted when the UA drops an incoming SIP request (e.g. wrong URI,
/// sanity-check failure, parse error). Diagnostics only.
class EventSipRequestDropped extends EventType {
  EventSipRequestDropped({this.method, this.reason, this.callId});
  String? method;
  String? reason;
  String? callId;
}

/// Emitted when an outbound SIP request (e.g. BYE) is dispatched to the
/// transport. Proves the message left the app toward the network.
class EventSipRequestSent extends EventType {
  EventSipRequestSent({this.method, this.to, this.callId});
  String? method;
  String? to;
  String? callId;
}

/// Emitted when we receive a response (or timeout/error) for an outbound SIP
/// request. [outcome] is one of: 'success', 'error', 'dialogError', 'timeout',
/// 'transportError'.
class EventSipResponseReceived extends EventType {
  EventSipResponseReceived(
      {this.method, this.statusCode, this.outcome, this.callId});
  String? method;
  int? statusCode;
  String? outcome;
  String? callId;
}

/// Emitted when the ICE connection state changes on an active RTCSession.
/// Diagnostics only — helps trace ICE negotiation failures.
class EventIceConnectionState extends EventType {
  EventIceConnectionState({this.state, this.callId});
  String? state;
  String? callId;
}

/// Emitted when the ICE gathering state changes (new → gathering → complete).
/// Diagnostics only — helps trace whether candidates are being gathered.
class EventIceGatheringState extends EventType {
  EventIceGatheringState({this.state, this.callId});
  String? state;
  String? callId;
}

/// Emitted when an ICE candidate is discovered. Carries the raw SDP candidate
/// string for diagnostics (candidate type, transport). Named differently from
/// the internal [EventIceCandidate] which carries the full RTCIceCandidate
/// object + ready callback.
class EventIceCandidateDiagnostic extends EventType {
  EventIceCandidateDiagnostic({this.candidate, this.callId});
  String? candidate;
  String? callId;
}

/// Emitted when an ICE restart is attempted after a prolonged disconnect.
class EventIceRestart extends EventType {
  EventIceRestart({this.callId});
  String? callId;
}
