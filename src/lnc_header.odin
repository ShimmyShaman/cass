package launcher

import "core:strings"
import "core:sync"
import "core:thread"
import "core:time"

import enet "vendor:ENet"

import vi "violin:vsr"
import vig "violin:gui"

import cn "common:net"
import cg "common:ag"

LauncherError :: enum {
  Success,
  NotYetDetailed = auto_cast vi.Error.MAX_EXTENT_VALUE,
  DEBUG_SuppressLaunchClient,
  NetworkError,
  AllocationFailed,
  FailedToOpenCurrentDirectory,
  FailedToReadCurrentDirectory,
  FailedToReadDirectoryFile,
  FailedToObtainGameVersion,
}

LauncherState :: enum {
  Initializing,
  ConnectingToServer,
  RetrievingServiceInfo,
  ClientVerified,
  FatalError,
}

ExistingFileSearch :: struct {
  current_file_list: [dynamic]ClientGameFile,
}

AlternateThreadState :: enum {
  Uninitiated,
  Running,
  Stopped,
}

ManifestVerficationStatusType :: enum {
  CollectingCurrentFileList,
  AwaitingRemoteManifest,
  VerifyingClientFiles,
  DownloadingGameFiles,
  Verified,
}

GameFileTransfer :: struct {
  file_info: RemoteGameFile,
  bytes_downloaded: u32,
  start_time: time.Time,
  data: []u8,
}

ServiceInfo :: struct {
  status: cn.ServiceStatus,
  retry_time: time.Time,
  retry_count: u32,
}

ManifestInfo :: struct {
  remote_version: cg.GameVersion,
  remote_file_list: [dynamic]RemoteGameFile,
  verification_status: ManifestVerficationStatusType,
  using transfer: GameFileTransfer,

  retry_time: time.Time,
  retry_count: int,
}

LauncherData :: struct {
  // settings: ClientSettings,
  alt_thread: ^thread.Thread,
  alt_err: LauncherError,
  alt_state: AlternateThreadState,
  alt_sync: sync.Mutex,
  alt_data: union {
    ExistingFileSearch,
  },

  net: ^cn.ENetClient,
  vctx: ^vi.Context,
  gui: ^vig.GUIRoot,

  launch_client_on_exit: bool,

  strbld: strings.Builder,

  loop_start: time.Time,
  frame_elapsed, total_elapsed: f32,
  min_fps, max_fps: int,
  historical_frame_count: int,

  state: LauncherState,
  state_sync: sync.Mutex,
  state_transition_time: time.Time,
  state_retry_count: int,
  service: ServiceInfo,
  manifest: ManifestInfo,

  current_version: cg.GameVersion,
  auth_token: u32,
}

ClientGameFile :: struct {
  relative_path: string,
  size: u32,
  data_hash: u128,
}

RemoteGameFile :: struct {
  using _cgf: ClientGameFile,
  remote_id: u32,
}