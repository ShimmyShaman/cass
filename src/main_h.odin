package cass

import "core:strings"
import "core:sync"
import "core:thread"
import "core:time"

import vi "violin:vsr"
import vig "violin:gui"

CassAppError :: enum {
  Success,
  NotYetDetailed = auto_cast vi.Error.MAX_EXTENT_VALUE,
  NetworkError,
  AllocationFailed,
  FailedToOpenCurrentDirectory,
  FailedToReadCurrentDirectory,
  FailedToReadDirectoryFile,
}

CassState :: enum {
  Initializing,
  ConnectingToServer,
  RetrievingServiceInfo,
  ClientVerified,
  FatalError,
}

AlternateThreadState :: enum {
  Uninitiated,
  Running,
  Stopped,
}

CassAppData :: struct {
  // settings: ClientSettings,
  alt_thread: ^thread.Thread,
  alt_err: CassAppError,
  alt_state: AlternateThreadState,
  alt_sync: sync.Mutex,
  // alt_data: union {
  //   ExistingFileSearch,
  // },

  vctx: ^vi.Context,
  gui: ^vig.GUIRoot,

  strbld: strings.Builder,

  loop_start: time.Time,
  frame_elapsed, total_elapsed: f32,
  min_fps, max_fps: int,
  historical_frame_count: int,

  state: CassState,
  state_sync: sync.Mutex,
  state_transition_time: time.Time,
  state_retry_count: int,
}