import { Room, RoomEvent, Track } from 'livekit-client';
import type { RemoteTrack } from 'livekit-client';
import type { ConnState } from '../types';

export interface SubscribeOptions {
  url: string;
  token: string;
  videoEl: HTMLVideoElement;
  onState: (state: ConnState) => void;
}

/// Connects the browser as a subscriber-only participant and attaches the
/// owner's audio/video tracks to the page. No app install for the contact.
export async function subscribe(opts: SubscribeOptions): Promise<Room> {
  const room = new Room({ adaptiveStream: true, dynacast: false });

  room.on(RoomEvent.TrackSubscribed, (track: RemoteTrack) => {
    if (track.kind === Track.Kind.Video || track.kind === Track.Kind.Audio) {
      track.attach(opts.videoEl);
    }
  });
  room.on(RoomEvent.Connected, () => opts.onState('connected'));
  room.on(RoomEvent.Reconnecting, () => opts.onState('reconnecting'));
  room.on(RoomEvent.Reconnected, () => opts.onState('connected'));
  room.on(RoomEvent.Disconnected, () => opts.onState('disconnected'));

  opts.onState('connecting');
  await room.connect(opts.url, opts.token);
  return room;
}
