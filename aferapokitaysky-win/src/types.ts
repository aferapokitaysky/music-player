export interface Track {
  id: string;
  title: string;
  artist: string;
  albumArtUrl: string | null;
  audioUrl: string;
  duration: number;
}

export type AlbumKind = 'demo' | 'uploads' | 'likes' | 'playlist' | 'custom' | 'spotify';

export interface Album {
  id: string;
  name: string;
  kind: AlbumKind;
  artworkUrl: string | null;
  tracks: Track[];
}

export type SearchSource = 'soundCloud' | 'spotify';

export type VisualizerMode = 'bars' | 'wave' | 'circle' | 'dots';

export type LayoutBlock = 'albums' | 'tracks' | 'player';

export type PlayerBlock = 'meta' | 'visualizer' | 'controls';

export interface ThemePalette {
  appTint: string;
  sidebar: string;
  card: string;
  cardElevated: string;
  inset: string;
  stroke: string;
  strokeStrong: string;
  divider: string;
  textPrimary: string;
  textSecondary: string;
  textTertiary: string;
  accent: string;
  accentSoft: string;
  accentSecondary: string;
  accentGradient: string[];
  playGradient: string[];
  pauseGradient: string[];
  progressGradient: string[];
  closeColor: string;
  minimizeColor: string;
  maximizeColor: string;
  cardShadow: string;
  glow: string;
  playIconColor: string;
  pauseIconColor: string;
}

export type AppTheme = 'dark' | 'light' | 'custom';
