import { writable, get } from 'svelte/store';
import { invoke } from '@tauri-apps/api/core';
import { Track, Album, SearchSource, VisualizerMode, LayoutBlock, PlayerBlock } from './types';

// State management replica of Swift's PlayerViewModel
export const albums = writable<Album[]>([]);
export const selectedAlbumId = writable<string | null>(null);
export const playingAlbumId = writable<string | null>(null);
export const currentTrack = writable<Track | null>(null);
export const isPlaying = writable<boolean>(false);
export const isShuffle = writable<boolean>(false);
export const isRepeat = writable<boolean>(false);

// UI and layouts
export const sidebarCollapsed = writable<boolean>(false);
export const uiOpacity = writable<number>(parseFloat(localStorage.getItem('uiOpacity') || '0.60'));
export const visualEffectsEnabled = writable<boolean>(localStorage.getItem('visualEffectsEnabled') !== 'false');

// Services login
export const spotifyToken = writable<string>(localStorage.getItem('spotify_token') || '');
export const soundCloudOAuth = writable<string>(localStorage.getItem('soundcloud_oauth') || '');
export const soundCloudUrl = writable<string>(localStorage.getItem('soundCloudUrl') || '');
export const connectionStatus = writable<string>('');
export const isConnecting = writable<boolean>(false);

// Search overlay state
export const showSearchBar = writable<boolean>(false);
export const searchQuery = writable<string>('');
export const searchSource = writable<SearchSource>('soundCloud');
export const searchResults = writable<Track[]>([]);
export const isSearching = writable<boolean>(false);
export const searchStatus = writable<string>('');
export const searchTargetPlaylistId = writable<string | null>(null);

// History databases
export const recentQueriesStr = writable<string>(localStorage.getItem('recentQueries') || '');
export const recentSearchTracks = writable<Track[]>(JSON.parse(localStorage.getItem('recentSearchTracks') || '[]'));

// Frequency spectrum
export const visualizerBars = writable<number[]>(Array(28).fill(0));

// Layout orders
export const layoutOrder = writable<LayoutBlock[]>(
  (localStorage.getItem('layoutOrderString') || 'albums|tracks|player').split('|') as LayoutBlock[]
);
export const playerLayoutOrder = writable<PlayerBlock[]>(
  (localStorage.getItem('playerLayoutOrderString') || 'meta|visualizer|controls').split('|') as PlayerBlock[]
);

// Save variables helper
uiOpacity.subscribe(val => localStorage.setItem('uiOpacity', val.toString()));
visualEffectsEnabled.subscribe(val => localStorage.setItem('visualEffectsEnabled', val.toString()));
layoutOrder.subscribe(val => localStorage.setItem('layoutOrderString', val.join('|')));
playerLayoutOrder.subscribe(val => localStorage.setItem('playerLayoutOrderString', val.join('|')));

// Core playback actions
export async function playTrack(track: Track, albumId: string) {
  try {
    playingAlbumId.set(albumId);
    currentTrack.set(track);
    isPlaying.set(true);
    await invoke('play_track', { track });
    addTrackToSearchHistory(track);
  } catch (err) {
    connectionStatus.set(`Playback error: ${err}`);
  }
}

export async function pauseTrack() {
  try {
    isPlaying.set(false);
    await invoke('pause_track');
  } catch (err) {
    connectionStatus.set(`Pause error: ${err}`);
  }
}

export async function setVolume(volume: number) {
  try {
    await invoke('set_volume', { volume });
  } catch (err) {
    console.error(err);
  }
}

// History handlers
export function addTrackToSearchHistory(track: Track) {
  let history = get(recentSearchTracks);
  history = history.filter(t => t.id !== track.id);
  history.unshift(track);
  if (history.count > 6) {
    history = history.slice(0, 6);
  }
  recentSearchTracks.set(history);
  localStorage.setItem('recentSearchTracks', JSON.stringify(history));
}

export function clearSearchHistory() {
  recentSearchTracks.set([]);
  localStorage.removeItem('recentSearchTracks');
}

export function addRecentQuery(query: string) {
  const trimmed = query.trim();
  if (!trimmed) return;
  let queries = get(recentQueriesStr).split('|').filter(Boolean);
  queries = queries.filter(q => q !== trimmed);
  queries.unshift(trimmed);
  if (queries.length > 5) {
    queries = queries.slice(0, 5);
  }
  const serialized = queries.join('|');
  recentQueriesStr.set(serialized);
  localStorage.setItem('recentQueries', serialized);
}

export function clearRecentQueries() {
  recentQueriesStr.set('');
  localStorage.removeItem('recentQueries');
}
