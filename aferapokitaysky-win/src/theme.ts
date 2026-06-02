import { ThemePalette, AppTheme } from './types';

export const darkPalette: ThemePalette = {
  appTint: 'rgba(0, 0, 0, 0.18)',
  sidebar: 'rgba(0, 0, 0, 0.40)',
  card: 'rgba(255, 255, 255, 0.04)',
  cardElevated: 'rgba(0, 0, 0, 0.45)',
  inset: 'rgba(255, 255, 255, 0.05)',
  stroke: 'rgba(255, 255, 255, 0.09)',
  strokeStrong: 'rgba(255, 255, 255, 0.18)',
  divider: 'rgba(255, 255, 255, 0.07)',
  textPrimary: '#FFFFFF',
  textSecondary: '#B8B8B8',
  textTertiary: '#737373',
  accent: '#FFFFFF',
  accentSoft: 'rgba(255, 255, 255, 0.10)',
  accentSecondary: '#B3B3B3',
  accentGradient: ['#FFFFFF', '#B8B8B8', '#6B6B6B'],
  playGradient: ['#FFFFFF', '#C7C7C7'],
  pauseGradient: ['#DBDBDB', '#8C8C8C'],
  progressGradient: ['#FFFFFF', '#A6A6A6'],
  closeColor: '#FF5E5C',
  minimizeColor: '#FFBD2E',
  maximizeColor: '#4FCE5E',
  cardShadow: 'rgba(0, 0, 0, 0.55)',
  glow: 'rgba(255, 255, 255, 0.30)',
  playIconColor: '#1F1F1F',
  pauseIconColor: '#1F1F1F',
};

export const lightPalette: ThemePalette = {
  appTint: 'rgba(255, 255, 255, 0.25)',
  sidebar: 'rgba(255, 255, 255, 0.55)',
  card: 'rgba(0, 0, 0, 0.03)',
  cardElevated: 'rgba(255, 255, 255, 0.78)',
  inset: 'rgba(0, 0, 0, 0.05)',
  stroke: 'rgba(0, 0, 0, 0.08)',
  strokeStrong: 'rgba(0, 0, 0, 0.16)',
  divider: 'rgba(0, 0, 0, 0.07)',
  textPrimary: '#000000',
  textSecondary: '#525252',
  textTertiary: '#8C8C8C',
  accent: '#000000',
  accentSoft: 'rgba(0, 0, 0, 0.06)',
  accentSecondary: '#666666',
  accentGradient: ['#000000', '#4D4D4D', '#8C8C8C'],
  playGradient: ['#000000', '#404040'],
  pauseGradient: ['#333333', '#808080'],
  progressGradient: ['#000000', '#595959'],
  closeColor: '#FF5E5C',
  minimizeColor: '#FFBD2E',
  maximizeColor: '#4FCE5E',
  cardShadow: 'rgba(0, 0, 0, 0.10)',
  glow: 'rgba(0, 0, 0, 0.20)',
  playIconColor: '#FFFFFF',
  pauseIconColor: '#FFFFFF',
};

export function getCustomPalette(
  accentHex = '#FF5500',
  sidebarHex = '#111111',
  tintHex = '#000000',
  cardHex = '#222222',
  textHex = '#FFFFFF',
  progressHex = '#FF5500',
  glowHex = '#FF5500'
): ThemePalette {
  return {
    appTint: `${tintHex}2E`, // 18% opacity
    sidebar: `${sidebarHex}66`, // 40% opacity
    card: `${cardHex}0A`, // 4% opacity
    cardElevated: `${sidebarHex}73`, // 45% opacity
    inset: `${cardHex}0D`, // 5% opacity
    stroke: `${textHex}17`, // 9% opacity
    strokeStrong: `${textHex}2E`, // 18% opacity
    divider: `${textHex}12`, // 7% opacity
    textPrimary: textHex,
    textSecondary: `${textHex}B8`, // 72% opacity
    textTertiary: `${textHex}73`, // 45% opacity
    accent: accentHex,
    accentSoft: `${accentHex}1A`, // 10% opacity
    accentSecondary: `${accentHex}B3`, // 70% opacity
    accentGradient: [accentHex, `${accentHex}BF`, `${accentHex}80`],
    playGradient: [accentHex, `${accentHex}CC`],
    pauseGradient: [`${textHex}CC`, `${textHex}80`],
    progressGradient: [progressHex, `${progressHex}B3`],
    closeColor: '#FF5E5C',
    minimizeColor: '#FFBD2E',
    maximizeColor: '#4FCE5E',
    cardShadow: 'rgba(0, 0, 0, 0.55)',
    glow: `${glowHex}4D`, // 30% opacity
    playIconColor: '#1F1F1F',
    pauseIconColor: '#1F1F1F',
  };
}

export function getPaletteForTheme(theme: AppTheme): ThemePalette {
  if (theme === 'dark') return darkPalette;
  if (theme === 'light') return lightPalette;
  
  // Custom theme variables loaded from localStorage (matching UserDefaults.standard)
  const customAccent = localStorage.getItem('customAccent') || '#FF5500';
  const customSidebar = localStorage.getItem('customSidebar') || '#111111';
  const customAppTint = localStorage.getItem('customAppTint') || '#000000';
  const customCard = localStorage.getItem('customCard') || '#222222';
  const customText = localStorage.getItem('customTextPrimary') || '#FFFFFF';
  const customProgress = localStorage.getItem('customProgress') || '#FF5500';
  const customGlow = localStorage.getItem('customGlow') || '#FF5500';

  return getCustomPalette(
    customAccent,
    customSidebar,
    customAppTint,
    customCard,
    customText,
    customProgress,
    customGlow
  );
}
