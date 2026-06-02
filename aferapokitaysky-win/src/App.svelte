<script lang="ts">
  import { onMount } from 'svelte';
  import { get } from 'svelte/store';
  import { AppTheme, ThemePalette, LayoutBlock, PlayerBlock } from './types';
  import { getPaletteForTheme } from './theme';
  import { 
    albums, selectedAlbumId, playingAlbumId, currentTrack, isPlaying, 
    uiOpacity, sidebarCollapsed, showSearchBar, searchQuery, searchSource, 
    searchResults, isSearching, searchStatus, layoutOrder, playerLayoutOrder,
    recentQueriesStr, recentSearchTracks, addRecentQuery, clearRecentQueries,
    clearSearchHistory, playTrack, pauseTrack, setVolume
  } from './playerStore';
  import Visualizer from './components/Visualizer.svelte';

  let theme: AppTheme = (localStorage.getItem('theme') as AppTheme) || 'dark';
  $: palette = getPaletteForTheme(theme);

  // Set colors dynamically in CSS variables
  $: cssVariables = `
    --app-tint: ${palette.appTint};
    --sidebar-color: ${palette.sidebar};
    --card-color: ${palette.card};
    --card-elevated: ${palette.cardElevated};
    --inset-color: ${palette.inset};
    --stroke-color: ${palette.stroke};
    --stroke-strong: ${palette.strokeStrong};
    --divider-color: ${palette.divider};
    --text-primary: ${palette.textPrimary};
    --text-secondary: ${palette.textSecondary};
    --text-tertiary: ${palette.textTertiary};
    --accent-color: ${palette.accent};
    --glow-color: ${palette.glow};
  `;

  function toggleTheme() {
    theme = theme === 'dark' ? 'light' : theme === 'light' ? 'custom' : 'dark';
    localStorage.setItem('theme', theme);
  }

  // Keyboard shortcut listener to mimic Swift window handlers
  onMount(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape' && get(showSearchBar)) {
        showSearchBar.set(false);
      }
      if (e.metaKey && e.key.toLowerCase() === 's' && get(showSearchBar)) {
        e.preventDefault();
        searchSource.update(s => s === 'soundCloud' ? 'spotify' : 'soundCloud');
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  });
</script>

<div class="app-container" style={cssVariables}>
  <!-- Background blur panel matching NSVisualEffectView -->
  <div class="backdrop" style="opacity: {$uiOpacity}"></div>

  <!-- Main Grid Layout ordered by layoutOrder -->
  <div class="columns-container">
    {#each $layoutOrder as block}
      {#if block === 'albums' && !$sidebarCollapsed}
        <div class="column sidebar" style="width: 200px; background: var(--sidebar-color)">
          <div class="window-drag-area"></div>
          <div class="header">
            <div class="logo"></div>
            <div class="brand">
              <span class="title">Aferapokitaysky</span>
              <span class="subtitle">Player · Pro</span>
            </div>
          </div>
          
          <div class="menu-items scrollable">
            <div class="section-label">БИБЛИОТЕКА</div>
            {#each $albums as album}
              <button 
                class="album-row" 
                class:active={$selectedAlbumId === album.id}
                on:click={() => selectedAlbumId.set(album.id)}
              >
                <span class="icon">💿</span>
                <span class="name">{album.name}</span>
              </button>
            {/each}
          </div>

          <div class="footer">
            <button class="footer-btn" on:click={toggleTheme} title="Сменить тему">
              {theme === 'dark' ? '🌙' : '☀️'}
            </button>
            <button class="footer-btn" title="Настройки">⚙️</button>
            <button class="footer-btn" on:click={() => sidebarCollapsed.set(true)} title="Скрыть альбомы">
              📂
            </button>
          </div>
        </div>
      {:else if block === 'tracks'}
        <div class="column tracks" style="width: 360px;">
          <div class="header-toolbar">
            {#if $sidebarCollapsed}
              <button class="icon-btn" on:click={() => sidebarCollapsed.set(false)} title="Показать альбомы">
                📂
              </button>
            {/if}
            <button class="search-btn" on:click={() => showSearchBar.set(true)}>
              🔍 Поиск
            </button>
          </div>

          <div class="tracks-list scrollable">
            <!-- Render tracks of selectedAlbum -->
          </div>
        </div>
      {:else if block === 'player'}
        <div class="column player">
          {#each $playerLayoutOrder as pBlock}
            {#if pBlock === 'meta'}
              <div class="player-meta">
                {#if $currentTrack}
                  <img src={$currentTrack.albumArtUrl || ''} alt="Artwork" class="artwork" />
                  <div class="info">
                    <div class="title">{$currentTrack.title}</div>
                    <div class="artist">{$currentTrack.artist}</div>
                  </div>
                {:else}
                  <div class="no-track">Нет трека</div>
                {/if}
              </div>
            {:else if pBlock === 'visualizer'}
              <div class="player-visualizer">
                <Visualizer mode="bars" {palette} />
              </div>
            {:else if pBlock === 'controls'}
              <div class="player-controls">
                <button class="control-btn" on:click={$isPlaying ? pauseTrack : () => $currentTrack && playTrack($currentTrack, $playingAlbumId || 'demo')}>
                  {$isPlaying ? '⏸' : '▶️'}
                </button>
                <input type="range" min="0" max="1" step="0.05" value="0.8" on:input={(e) => setVolume(parseFloat(e.currentTarget.value))} class="volume-slider" />
              </div>
            {/if}
          {/each}
        </div>
      {/if}
      
      <!-- Divider between columns -->
      {#if block !== $layoutOrder[$layoutOrder.length - 1]}
        <div class="divider"></div>
      {/if}
    {/each}
  </div>

  <!-- Spotlight Search Overlay Container -->
  {#if $showSearchBar}
    <div class="search-overlay" on:click={() => showSearchBar.set(false)}>
      <div class="search-card" on:click|stopPropagation>
        <!-- Search input header -->
        <div class="search-header">
          <input 
            type="text" 
            bind:value={$searchQuery} 
            placeholder={$searchSource === 'soundCloud' ? 'Поиск треков в SoundCloud...' : 'Поиск треков в Spotify...'} 
            class="search-input"
            autoFocus
          />
        </div>

        <!-- Search switchers -->
        <div class="search-tabs">
          <button class:active={$searchSource === 'soundCloud'} on:click={() => searchSource.set('soundCloud')}>SoundCloud</button>
          <button class:active={$searchSource === 'spotify'} on:click={() => searchSource.set('spotify')}>Spotify</button>
        </div>

        <div class="search-content scrollable">
          {#if $searchQuery === ''}
            <!-- Recent queries & play histories -->
            {#if $recentSearchTracks.length > 0}
              <div class="history-section">
                <div class="section-title">ИСТОРИЯ ЗАПУСКОВ</div>
                {#each $recentSearchTracks as track}
                  <div class="track-row">
                    <button class="mini-play" on:click={() => playTrack(track, 'search_history')}>▶</button>
                    <span class="title">{track.title}</span>
                    <span class="artist">{track.artist}</span>
                  </div>
                {/each}
              </div>
            {/if}
          {:else}
            <!-- Live search results -->
          {/if}
        </div>
      </div>
    </div>
  {/if}
</div>

<style>
  .app-container {
    position: relative;
    width: 100vw;
    height: 100vh;
    display: flex;
    background-color: transparent;
    color: var(--text-primary);
  }

  .backdrop {
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: var(--app-tint);
    backdrop-filter: blur(25px);
    z-index: -1;
  }

  .columns-container {
    display: flex;
    width: 100%;
    height: 100%;
  }

  .column {
    display: flex;
    flex-direction: column;
    height: 100%;
  }

  .divider {
    width: 1px;
    height: 100%;
    background-color: var(--divider-color);
  }

  /* Specific styles for sidebars, control cards, search overlay mimics */
  .sidebar {
    padding: 14px 0;
  }

  .scrollable {
    flex: 1;
    overflow-y: auto;
  }

  .search-overlay {
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background-color: rgba(0, 0, 0, 0.4);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 2000;
  }

  .search-card {
    width: 620px;
    height: 500px;
    background: var(--card-elevated);
    border: 1px solid var(--stroke-color);
    border-radius: 18px;
    display: flex;
    flex-direction: column;
  }
</style>
