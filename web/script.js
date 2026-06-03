// Global variables for Player state
let isPlaying = false;
let currentVisualizerMode = 'bars'; // bars, wave, circle, dots
let trackProgress = 35; // percentage
let playProgressInterval;

// Track library database
const demoTracks = [
    { title: "Европа ФМ", artist: "tuborosho", duration: "1:52", cover: "cover-1" },
    { title: "Мой Флоу Со Справкой", artist: "Anonymous Ember", duration: "1:55", cover: "cover-2" },
    { title: "NICKI MINAJ", artist: "Anonymous Ember", duration: "1:37", cover: "cover-3" }
];

const mockAlbums = {
    likes: demoTracks,
    charts: demoTracks,
    local: demoTracks
};
let currentPlaylist = 'likes';
let currentTrackIndex = 1;
let prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
const reducedMotionQuery = window.matchMedia('(prefers-reduced-motion: reduce)');

if (reducedMotionQuery.addEventListener) {
    reducedMotionQuery.addEventListener('change', (event) => {
        prefersReducedMotion = event.matches;
        syncParticleDensity();
    });
}

// Frequencies for visualizer
let barsCount = 36;
let frequencies = Array(barsCount).fill(0);

// Canvas references
const visCanvas = document.getElementById('visualizer-canvas');
const visCtx = visCanvas.getContext('2d');

const partCanvas = document.getElementById('ambient-particles');
const partCtx = partCanvas.getContext('2d');

// --- BACKGROUND PARTICLE SYSTEM (Cosmic Dust) ---
let particles = [];
let particleResizeTick = null;
const particleColors = ['#ffffff', '#bafcff', '#ffe08a', '#9b9b9b'];
const pointer = { x: -9999, y: -9999, active: false };

function getParticleTargetCount() {
    const area = window.innerWidth * window.innerHeight;
    const target = Math.round(area / 15000);
    return prefersReducedMotion ? 26 : Math.max(48, Math.min(145, target));
}

function createParticle(width = window.innerWidth, height = window.innerHeight) {
    const angle = Math.random() * Math.PI * 2;
    const speed = Math.random() * 0.24 + 0.08;
    const depth = Math.random() * 0.8 + 0.25;
    return {
        x: Math.random() * width,
        y: Math.random() * height,
        vx: Math.cos(angle) * speed,
        vy: Math.sin(angle) * speed,
        depth,
        size: Math.random() * 1.9 + 0.55,
        opacity: Math.random() * 0.42 + 0.14,
        color: particleColors[Math.floor(Math.random() * particleColors.length)]
    };
}

function initParticles() {
    particles = Array.from({ length: getParticleTargetCount() }, () => createParticle());
}

function syncParticleDensity() {
    const target = getParticleTargetCount();
    while (particles.length < target) {
        particles.push(createParticle());
    }
    if (particles.length > target) {
        particles.length = target;
    }
}

function resizeParticlesCanvas() {
    const dpr = window.devicePixelRatio || 1;
    partCanvas.width = Math.floor(window.innerWidth * dpr);
    partCanvas.height = Math.floor(window.innerHeight * dpr);
    partCanvas.style.width = `${window.innerWidth}px`;
    partCanvas.style.height = `${window.innerHeight}px`;
    partCtx.setTransform(dpr, 0, 0, dpr, 0, 0);
    syncParticleDensity();
}
window.addEventListener('resize', () => {
    if (particleResizeTick) cancelAnimationFrame(particleResizeTick);
    particleResizeTick = requestAnimationFrame(() => {
        resizeParticlesCanvas();
        resizeVisCanvas();
    });
});

window.addEventListener('pointermove', (event) => {
    pointer.x = event.clientX;
    pointer.y = event.clientY;
    pointer.active = true;
});

window.addEventListener('pointerleave', () => {
    pointer.active = false;
});
resizeParticlesCanvas();
initParticles();

// Simulate bass beat peak
let simulatedBass = 0;

function drawParticles() {
    const width = window.innerWidth;
    const height = window.innerHeight;
    partCtx.clearRect(0, 0, width, height);
    
    // speed multiplier increases if playing and based on bass frequency peaks
    const speedMultiplier = prefersReducedMotion ? 0.05 : 0.72 + (isPlaying ? simulatedBass * 6.2 : 0.0);
    const opacityMultiplier = isPlaying ? (0.62 + simulatedBass * 0.52) : 0.38;
    const padding = 20;

    for (let i = 0; i < particles.length; i++) {
        const p = particles[i];
        const pointerDx = p.x - pointer.x;
        const pointerDy = p.y - pointer.y;
        const pointerDistance = Math.hypot(pointerDx, pointerDy);

        if (pointer.active && pointerDistance < 120 && pointerDistance > 0) {
            const push = (120 - pointerDistance) / 120;
            p.vx += (pointerDx / pointerDistance) * push * 0.012;
            p.vy += (pointerDy / pointerDistance) * push * 0.012;
        }
        
        // Move particle
        p.x += p.vx * speedMultiplier * p.depth;
        p.y += p.vy * speedMultiplier * p.depth;
        p.vx *= 0.995;
        p.vy *= 0.995;

        // Wrap boundaries
        if (p.x < -padding) p.x = width + padding;
        else if (p.x > width + padding) p.x = -padding;

        if (p.y < -padding) p.y = height + padding;
        else if (p.y > height + padding) p.y = -padding;

        // Draw particle
        partCtx.fillStyle = p.color;
        partCtx.globalAlpha = p.opacity * opacityMultiplier;
        partCtx.beginPath();
        partCtx.arc(p.x, p.y, p.size * (isPlaying ? 1 + simulatedBass * 0.35 : 1), 0, Math.PI * 2);
        partCtx.fill();

        if (!prefersReducedMotion && isPlaying) {
            for (let j = i + 1; j < particles.length; j++) {
                const n = particles[j];
                const dx = p.x - n.x;
                const dy = p.y - n.y;
                const distance = Math.hypot(dx, dy);
                if (distance < 84) {
                    partCtx.globalAlpha = (1 - distance / 84) * 0.1 * (0.4 + simulatedBass);
                    partCtx.strokeStyle = p.color;
                    partCtx.lineWidth = 0.6;
                    partCtx.beginPath();
                    partCtx.moveTo(p.x, p.y);
                    partCtx.lineTo(n.x, n.y);
                    partCtx.stroke();
                }
            }
        }
    }
    partCtx.globalAlpha = 1.0;
    requestAnimationFrame(drawParticles);
}
drawParticles();


// --- VISUALIZER DRAW LOOP ---
function resizeVisCanvas() {
    const dpr = window.devicePixelRatio || 1;
    visCanvas.width = Math.max(1, Math.floor(visCanvas.clientWidth * dpr));
    visCanvas.height = Math.max(1, Math.floor(visCanvas.clientHeight * dpr));
    visCtx.setTransform(dpr, 0, 0, dpr, 0, 0);
}
resizeVisCanvas();

function setVisualizerMode(mode) {
    currentVisualizerMode = mode;
    document.querySelectorAll('.vis-tab').forEach(tab => {
        tab.classList.remove('active');
        tab.setAttribute('aria-selected', 'false');
    });
    const btn = document.getElementById(`btn-vis-${mode}`);
    if (btn) {
        btn.classList.add('active');
        btn.setAttribute('aria-selected', 'true');
    }
}
setVisualizerMode(currentVisualizerMode);

function updateFrequencies() {
    // Generate simulated audio spectrum values
    simulatedBass = isPlaying ? (Math.sin(Date.now() * 0.01) * 0.35 + 0.55) * (0.8 + Math.random() * 0.2) : 0.05;
    
    frequencies = frequencies.map((f, i) => {
        let target = 0.02;
        if (isPlaying) {
            // Bass frequencies on the left, highs on the right
            if (i < 5) {
                target = simulatedBass * (0.85 + Math.random() * 0.15);
            } else {
                target = (Math.random() * 0.4 + 0.1) * (1 - (i / barsCount) * 0.5);
                // add nice rhythmic waves
                target += Math.sin(i * 0.25 - Date.now() * 0.015) * 0.12;
                target = Math.max(0.02, Math.min(1.0, target));
            }
        } else {
            // Soft resting vibration
            target = 0.01 + Math.sin(i * 0.1 + Date.now() * 0.002) * 0.02;
        }
        return f + (target - f) * 0.15; // Smooth transition
    });
}

function drawVisualizer() {
    const w = visCanvas.width / (window.devicePixelRatio || 1);
    const h = visCanvas.height / (window.devicePixelRatio || 1);
    
    visCtx.clearRect(0, 0, w, h);
    updateFrequencies();

    const accentColor = '#ffffff';
    const subColor = '#8c8c8c';
    const tintColor = 'rgba(255, 255, 255, 0.04)';

    if (currentVisualizerMode === 'bars') {
        const cellCount = 12;
        const hPad = 12;
        const vPad = 10;
        const spacing = 3;
        const cellGap = 2;
        const totalSpacing = spacing * (barsCount - 1);
        const barWidth = Math.max(2, (w - totalSpacing - hPad * 2) / barsCount);
        const cellHeight = Math.max(1, (h - vPad * 2 - cellGap * (cellCount - 1)) / cellCount);

        for (let i = 0; i < barsCount; i++) {
            const x = hPad + i * (barWidth + spacing);
            const activeCells = Math.round(frequencies[i] * cellCount);

            for (let c = 0; c < cellCount; c++) {
                const cellIndex = (cellCount - 1) - c; // 0 = bottom
                const isActive = cellIndex < activeCells;
                const y = vPad + c * (cellHeight + cellGap);

                visCtx.beginPath();
                if (visCtx.roundRect) {
                    visCtx.roundRect(x, y, barWidth, cellHeight, 1);
                } else {
                    visCtx.rect(x, y, barWidth, cellHeight);
                }
                
                if (isActive) {
                    const ratio = cellIndex / (cellCount - 1);
                    visCtx.fillStyle = ratio > 0.65 ? accentColor : subColor;
                } else {
                    visCtx.fillStyle = tintColor;
                }
                visCtx.fill();
            }
        }
    } 
    else if (currentVisualizerMode === 'wave') {
        // Draw Wave
        visCtx.lineWidth = 1.5;
        const midY = h / 2;
        const step = w / (barsCount - 1);

        const phases = [
            { offset: 0, color: '#ffffff', width: 2.2, opacity: 0.9 },
            { offset: Math.PI * 0.5, color: '#b3b3b3', width: 1.5, opacity: 0.6 },
            { offset: Math.PI * 1.1, color: '#666666', width: 1.0, opacity: 0.4 }
        ];

        phases.forEach(ph => {
            visCtx.beginPath();
            visCtx.strokeStyle = ph.color;
            visCtx.lineWidth = ph.width;
            visCtx.globalAlpha = ph.opacity;

            for (let i = 0; i < barsCount; i++) {
                const x = i * step;
                const sineFactor = Math.sin(i * 0.35 + ph.offset + (isPlaying ? Date.now() * 0.01 : Date.now() * 0.002));
                const yOffset = frequencies[i] * (h / 2.3) * sineFactor;
                const y = midY + yOffset;

                if (i === 0) {
                    visCtx.moveTo(x, y);
                } else {
                    const prevX = (i - 1) * step;
                    const prevSine = Math.sin((i - 1) * 0.35 + ph.offset + (isPlaying ? Date.now() * 0.01 : Date.now() * 0.002));
                    const prevY = midY + frequencies[i - 1] * (h / 2.3) * prevSine;
                    
                    const cx1 = prevX + step / 2;
                    const cy1 = prevY;
                    const cx2 = prevX + step / 2;
                    const cy2 = y;
                    visCtx.bezierCurveTo(cx1, cy1, cx2, cy2, x, y);
                }
            }
            // Laser Ribbon Glow Effect
            visCtx.shadowColor = ph.color;
            visCtx.shadowBlur = isPlaying ? 12 : 3;
            visCtx.stroke();
            visCtx.shadowBlur = 0; // reset
        });
        visCtx.globalAlpha = 1.0;
    } 
    else if (currentVisualizerMode === 'circle') {
        const center = { x: w / 2, y: h / 2 };
        const maxRadius = Math.min(w, h) / 2.2;
        const minRadius = maxRadius * 0.45;

        // Draw ambient inner circle
        visCtx.strokeStyle = 'rgba(255, 255, 255, 0.08)';
        visCtx.lineWidth = 1;
        visCtx.beginPath();
        visCtx.arc(center.x, center.y, minRadius, 0, Math.PI * 2);
        visCtx.stroke();

        const angleStep = (Math.PI * 2) / barsCount;

        for (let i = 0; i < barsCount; i++) {
            const angle = i * angleStep;
            const barVal = frequencies[i];
            
            const startX = center.x + Math.cos(angle) * minRadius;
            const startY = center.y + Math.sin(angle) * minRadius;
            
            const length = (maxRadius - minRadius) * barVal;
            const endX = center.x + Math.cos(angle) * (minRadius + Math.max(2, length));
            const endY = center.y + Math.sin(angle) * (minRadius + Math.max(2, length));

            visCtx.beginPath();
            visCtx.moveTo(startX, startY);
            visCtx.lineTo(endX, endY);

            visCtx.strokeStyle = `rgba(255, 255, 255, ${0.35 + barVal * 0.65})`;
            visCtx.lineWidth = Math.max(1.5, (Math.PI * 2 * minRadius) / barsCount - 1);
            visCtx.lineCap = 'round';
            visCtx.stroke();
        }
    } 
    else if (currentVisualizerMode === 'dots') {
        const dotsPerColumn = 8;
        const hPad = 12;
        const vPad = 12;
        const spacing = 4;
        const dotGap = 3;
        
        const colWidth = Math.max(2, (w - spacing * (barsCount - 1) - hPad * 2) / barsCount);
        const dotHeight = Math.max(2, (h - vPad * 2 - dotGap * (dotsPerColumn - 1)) / dotsPerColumn);
        const dotSize = Math.min(colWidth, dotHeight);

        for (let i = 0; i < barsCount; i++) {
            const x = hPad + i * (colWidth + spacing) + (colWidth - dotSize) / 2;
            const activeDots = Math.round(frequencies[i] * dotsPerColumn);

            for (let d = 0; d < dotsPerColumn; d++) {
                const dotIndex = (dotsPerColumn - 1) - d;
                const isActive = dotIndex < activeDots;
                const y = vPad + d * (dotSize + dotGap) + (dotHeight - dotSize) / 2;

                visCtx.beginPath();
                visCtx.arc(x + dotSize / 2, y + dotSize / 2, dotSize / 2, 0, Math.PI * 2);
                
                if (isActive) {
                    const ratio = dotIndex / (dotsPerColumn - 1);
                    visCtx.fillStyle = `rgba(255, 255, 255, ${0.4 + ratio * 0.6})`;
                } else {
                    visCtx.fillStyle = 'rgba(255, 255, 255, 0.04)';
                }
                visCtx.fill();
            }
        }
    }

    requestAnimationFrame(drawVisualizer);
}
drawVisualizer();


// --- PLAYER LOGIC ---
function togglePlayState() {
    isPlaying = !isPlaying;
    const playSvg = document.getElementById('play-svg');
    const playButton = document.getElementById('play-pause-toggle');
    document.body.classList.toggle('is-playing', isPlaying);
    if (playButton) playButton.setAttribute('aria-pressed', String(isPlaying));
    if (isPlaying) {
        if (playSvg) {
            playSvg.innerHTML = '<path d="M6 19h4V5H6v14zm8-14v14h4V5h-4z"/>';
            playSvg.classList.remove('play');
        }
        playProgressInterval = setInterval(() => {
            trackProgress = (trackProgress + 0.35) % 100;
            updateProgressUI();
        }, 100);
    } else {
        if (playSvg) {
            playSvg.innerHTML = '<path d="M8 5v14l11-7z"/>';
            playSvg.classList.add('play');
        }
        clearInterval(playProgressInterval);
    }
}

function durationToSeconds(duration) {
    const [minutes, seconds] = duration.split(':').map(Number);
    return minutes * 60 + seconds;
}

function formatTime(totalSeconds) {
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = Math.floor(totalSeconds % 60);
    return `${minutes}:${String(seconds).padStart(2, '0')}`;
}

function getCurrentTrack() {
    return mockAlbums[currentPlaylist][currentTrackIndex] || demoTracks[0];
}

function findTrack(title, artist) {
    return demoTracks.find(track => track.title === title && track.artist === artist) || demoTracks.find(track => track.title === title) || demoTracks[0];
}

function updateProgressUI() {
    const progress = Math.max(0, Math.min(100, trackProgress));
    const track = getCurrentTrack();
    const duration = durationToSeconds(track.duration);
    const currentSeconds = Math.round((progress / 100) * duration);
    const progressBar = document.getElementById('track-progress');
    const heroProgress = document.getElementById('hero-progress');
    const currentTime = document.getElementById('demo-current-time');
    const totalTime = document.getElementById('demo-total-time');

    if (progressBar) progressBar.style.width = `${progress}%`;
    if (heroProgress) heroProgress.style.width = `${progress}%`;
    if (currentTime) currentTime.textContent = formatTime(currentSeconds);
    if (totalTime) totalTime.textContent = track.duration;
}

function updateCover(track) {
    const cover = document.getElementById('current-cover');
    if (!cover) return;
    cover.classList.remove('cover-1', 'cover-2', 'cover-3');
    cover.classList.add(track.cover);
}

function updateActiveTrackRow() {
    const tracksElements = document.querySelectorAll('.mock-track');
    tracksElements.forEach((el, index) => {
        el.classList.toggle('active', index === currentTrackIndex);
    });
}

function playTrackAt(index) {
    const list = mockAlbums[currentPlaylist];
    currentTrackIndex = (index + list.length) % list.length;
    const track = getCurrentTrack();
    playMockTrack(track.title, track.artist, track.duration);
}

function playMockTrack(title, artist, duration) {
    const track = findTrack(title, artist);
    const trackIndex = mockAlbums[currentPlaylist].findIndex(item => item.title === track.title && item.artist === track.artist);
    if (trackIndex >= 0) currentTrackIndex = trackIndex;

    document.getElementById('nowplaying-title').textContent = track.title;
    document.getElementById('nowplaying-artist').textContent = track.artist;
    const heroTitle = document.getElementById('hero-now-title');
    const heroArtist = document.getElementById('hero-now-artist');
    if (heroTitle) heroTitle.textContent = track.title;
    if (heroArtist) heroArtist.textContent = track.artist;
    document.title = `${track.title} - ${track.artist} | Aferapokitaysky Player`;
    updateCover(track);
    updateActiveTrackRow();
    
    // Reset track progress
    trackProgress = 0;
    updateProgressUI();
    
    // Automatically switch playing state to playing
    if (!isPlaying) {
        togglePlayState();
    }
}

function selectMockAlbum(albumKey) {
    currentPlaylist = albumKey;
    currentTrackIndex = 0;
    
    // Update active UI sidebar selector
    const items = document.querySelectorAll('.mock-sidebar .mock-item');
    items.forEach(el => el.classList.remove('active'));
    
    const indexMap = { likes: 0, charts: 1, local: 2 };
    items[indexMap[albumKey]].classList.add('active');
    document.querySelectorAll('.hero-chip').forEach((chip, index) => {
        chip.classList.toggle('active', index === indexMap[albumKey]);
    });

    // Update track list container
    const tracksContainer = document.getElementById('mock-tracks-container');
    tracksContainer.innerHTML = '';
    
    mockAlbums[albumKey].forEach((track, index) => {
        const item = document.createElement('button');
        item.type = 'button';
        item.className = 'mock-track app-track' + (index === 0 ? ' active' : '');
        item.onclick = () => {
            currentTrackIndex = index;
            playMockTrack(track.title, track.artist, track.duration);
        };

        item.innerHTML = `
            <span class="track-cover ${track.cover}"></span>
            <span class="track-info"><strong>${track.title}</strong><em>${track.artist}</em></span>
            <span class="time">${track.duration}</span>
        `;
        tracksContainer.appendChild(item);
    });

    // Play first track of selected album
    const first = mockAlbums[albumKey][0];
    playMockTrack(first.title, first.artist, first.duration);
}

function prevMockTrack() {
    const list = mockAlbums[currentPlaylist];
    currentTrackIndex = (currentTrackIndex - 1 + list.length) % list.length;
    updateTrackSelection();
}

function nextMockTrack() {
    const list = mockAlbums[currentPlaylist];
    currentTrackIndex = (currentTrackIndex + 1) % list.length;
    updateTrackSelection();
}

function updateTrackSelection() {
    const track = mockAlbums[currentPlaylist][currentTrackIndex];
    playMockTrack(track.title, track.artist, track.duration);
}


// --- MOCKUP CONFIGURATOR/CUSTOMIZER ---
let colOrder = [1, 2, 3];
function shiftColumns(direction) {
    const sidebar = document.getElementById('block-sidebar');
    const tracks = document.getElementById('block-tracks');
    const player = document.getElementById('block-player');

    if (direction > 0) {
        colOrder.push(colOrder.shift());
    } else {
        colOrder.unshift(colOrder.pop());
    }

    sidebar.style.order = colOrder[0];
    tracks.style.order = colOrder[1];
    player.style.order = colOrder[2];
}

let playerBlocks = ['p-meta', 'p-visualizer', 'p-controls'];
function shiftPlayerBlocks(direction) {
    const meta = document.getElementById('p-meta');
    const visualizer = document.getElementById('p-visualizer');
    const controls = document.getElementById('p-controls');

    if (direction > 0) {
        playerBlocks.push(playerBlocks.shift());
    } else {
        playerBlocks.unshift(playerBlocks.pop());
    }

    meta.style.order = playerBlocks.indexOf('p-meta') + 1;
    visualizer.style.order = playerBlocks.indexOf('p-visualizer') + 1;
    controls.style.order = playerBlocks.indexOf('p-controls') + 1;
}

// --- SPOTLIGHT SEARCH OVERLAY MOCKUP ---
let currentSearchSource = 'soundCloud';

function openSearchOverlay() {
    const overlay = document.getElementById('search-overlay');
    overlay.style.display = 'flex';
    document.getElementById('search-input').focus();
}

function closeSearchOverlay() {
    document.getElementById('search-overlay').style.display = 'none';
}

function setSearchSource(src) {
    currentSearchSource = src;
    document.getElementById('tab-sc').classList.toggle('active', src === 'soundCloud');
    document.getElementById('tab-sp').classList.toggle('active', src === 'spotify');
    
    const input = document.getElementById('search-input');
    if (src === 'soundCloud') {
        input.placeholder = "Поиск треков в SoundCloud...";
    } else {
        input.placeholder = "Поиск треков в Spotify...";
    }
    input.focus();
}

function handleSearchInput(e) {
    const query = e.target.value.toLowerCase();
    const list = document.getElementById('search-results-list');
    
    if (!query) {
        // Reset to original history view
        list.innerHTML = `
            <div class="history-section">
                <div class="section-title">ИСТОРИЯ ЗАПУСКОВ</div>
                <button type="button" class="track-row" onclick="playTrackAt(1); closeSearchOverlay()">
                    <span class="mini-play">
                        <svg viewBox="0 0 24 24" fill="currentColor" class="mini-play-svg" aria-hidden="true"><path d="M8 5v14l11-7z"/></svg>
                    </span>
                    <span>
                        <span class="track-name">Мой Флоу Со Справкой</span>
                        <span class="track-artist">Anonymous Ember</span>
                    </span>
                </button>
                <button type="button" class="track-row" onclick="playTrackAt(0); closeSearchOverlay()">
                    <span class="mini-play">
                        <svg viewBox="0 0 24 24" fill="currentColor" class="mini-play-svg" aria-hidden="true"><path d="M8 5v14l11-7z"/></svg>
                    </span>
                    <span>
                        <span class="track-name">Европа ФМ</span>
                        <span class="track-artist">tuborosho</span>
                    </span>
                </button>
            </div>
        `;
        return;
    }

    // Filter track search simulator
    const allTracks = demoTracks;

    const results = allTracks.filter(t => t.title.toLowerCase().includes(query) || t.artist.toLowerCase().includes(query));

    let html = `<div class="section-title">РЕЗУЛЬТАТЫ ПОИСКА (${currentSearchSource.toUpperCase()})</div>`;
    if (results.length === 0) {
        html += `<div style="color: var(--text-tertiary); font-size:12px; padding:10px;">Ничего не найдено</div>`;
    } else {
        results.forEach(track => {
            html += `
                <button type="button" class="track-row" onclick="playMockTrack('${track.title}', '${track.artist}', '${track.duration}'); closeSearchOverlay()">
                    <span class="mini-play">
                        <svg viewBox="0 0 24 24" fill="currentColor" class="mini-play-svg" aria-hidden="true"><path d="M8 5v14l11-7z"/></svg>
                    </span>
                    <span>
                        <span class="track-name">${track.title}</span>
                        <span class="track-artist">${track.artist}</span>
                    </span>
                </button>
            `;
        });
    }
    list.innerHTML = html;
}

// Global hotkey listner
window.addEventListener('keydown', (e) => {
    // Esc closes search overlay
    if (e.key === 'Escape') {
        closeSearchOverlay();
    }
    // Slash opens spotlight search
    if (e.key === '/' && document.activeElement.tagName !== 'INPUT') {
        e.preventDefault();
        openSearchOverlay();
    }
});

// Mock themes loop
const themes = ["Темная", "Светлая", "Космическая"];
let currentThemeIndex = 0;
function cycleMockTheme() {
    currentThemeIndex = (currentThemeIndex + 1) % themes.length;
    const btn = document.querySelector('.theme-toggle-btn span');
    if (btn) btn.innerText = `Тема: ${themes[currentThemeIndex]}`;
    
    // Toggle actual page styles to reflect visual adjustments
    const doc = document.documentElement;
    if (currentThemeIndex === 1) {
        // Light mode
        doc.style.setProperty('--bg-color', '#f5f5f7');
        doc.style.setProperty('--text-primary', '#000000');
        doc.style.setProperty('--text-secondary', '#525252');
        doc.style.setProperty('--text-tertiary', '#8c8c8c');
        doc.style.setProperty('--card-bg', 'rgba(0, 0, 0, 0.03)');
        doc.style.setProperty('--card-elevated', 'rgba(255, 255, 255, 0.85)');
        doc.style.setProperty('--card-border', 'rgba(0, 0, 0, 0.08)');
        doc.style.setProperty('--divider', 'rgba(0, 0, 0, 0.07)');
        doc.style.setProperty('--accent-aqua', '#007c89');
        doc.style.setProperty('--accent-warm', '#a25b00');
    } else if (currentThemeIndex === 2) {
        // Cosmic (custom blue-tinted)
        doc.style.setProperty('--bg-color', '#06060c');
        doc.style.setProperty('--text-primary', '#ffffff');
        doc.style.setProperty('--text-secondary', '#94a3b8');
        doc.style.setProperty('--text-tertiary', '#64748b');
        doc.style.setProperty('--card-bg', 'rgba(30, 41, 59, 0.25)');
        doc.style.setProperty('--card-elevated', 'rgba(15, 23, 42, 0.9)');
        doc.style.setProperty('--card-border', 'rgba(148, 163, 184, 0.1)');
        doc.style.setProperty('--divider', 'rgba(148, 163, 184, 0.08)');
        doc.style.setProperty('--accent-aqua', '#bafcff');
        doc.style.setProperty('--accent-warm', '#d9ff8f');
    } else {
        // Dark mode (default)
        doc.style.setProperty('--bg-color', '#000000');
        doc.style.setProperty('--text-primary', '#ffffff');
        doc.style.setProperty('--text-secondary', '#b8b8b8');
        doc.style.setProperty('--text-tertiary', '#737373');
        doc.style.setProperty('--card-bg', 'rgba(255, 255, 255, 0.04)');
        doc.style.setProperty('--card-elevated', 'rgba(6, 6, 8, 0.85)');
        doc.style.setProperty('--card-border', 'rgba(255, 255, 255, 0.08)');
        doc.style.setProperty('--divider', 'rgba(255, 255, 255, 0.07)');
        doc.style.setProperty('--accent-aqua', '#bafcff');
        doc.style.setProperty('--accent-warm', '#ffe08a');
    }
}

// --- CUSTOM CURSOR PHYSICS & INTERACTIVE HOVER STATE ---
const cursorDot = document.getElementById('cursor-dot');
const cursorRing = document.getElementById('cursor-ring');
let mouseX = -100, mouseY = -100;
let ringX = -100, ringY = -100;

window.addEventListener('mousemove', (e) => {
    mouseX = e.clientX;
    mouseY = e.clientY;
    
    if (cursorDot) {
        cursorDot.style.display = 'block';
        cursorDot.style.left = mouseX + 'px';
        cursorDot.style.top = mouseY + 'px';
    }
    if (cursorRing) {
        cursorRing.style.display = 'block';
    }
});

function tickCursor() {
    ringX += (mouseX - ringX) * 0.16;
    ringY += (mouseY - ringY) * 0.16;
    
    if (cursorRing) {
        cursorRing.style.left = ringX + 'px';
        cursorRing.style.top = ringY + 'px';
    }
    requestAnimationFrame(tickCursor);
}
tickCursor();

// Set up interactive cursor hover classes
const interactiveElements = 'a, button, [onclick], .mock-item, .mock-track, .btn, .search-tab, .track-row, input';
document.addEventListener('mouseover', (e) => {
    if (e.target.closest(interactiveElements)) {
        document.body.classList.add('hovering');
    }
});
document.addEventListener('mouseout', (e) => {
    if (e.target.closest(interactiveElements)) {
        document.body.classList.remove('hovering');
    }
});

// --- LIQUID GLASS HIGHLIGHT REFLECTION ENGINE ---
function updateLiquidHighlight(e) {
    const frame = document.getElementById('mockup-frame');
    if (!frame) return;
    const rect = frame.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;
    
    frame.style.setProperty('--mouse-x', `${x}px`);
    frame.style.setProperty('--mouse-y', `${y}px`);
}

// --- PAGE POLISH: HEADER, REVEAL, HERO GLASS ---
const header = document.querySelector('.header');
function updateHeaderState() {
    if (!header) return;
    header.classList.toggle('is-scrolled', window.scrollY > 18);
}
window.addEventListener('scroll', updateHeaderState, { passive: true });
updateHeaderState();

const revealObserver = 'IntersectionObserver' in window
    ? new IntersectionObserver((entries) => {
        entries.forEach((entry) => {
            if (entry.isIntersecting) {
                entry.target.classList.add('is-visible');
                revealObserver.unobserve(entry.target);
            }
        });
    }, { threshold: 0.16 })
    : null;

document.querySelectorAll('.reveal').forEach((section) => {
    if (revealObserver && !prefersReducedMotion) {
        revealObserver.observe(section);
    } else {
        section.classList.add('is-visible');
    }
});

const heroConsole = document.querySelector('.hero-console');
if (heroConsole) {
    heroConsole.addEventListener('pointermove', (event) => {
        const rect = heroConsole.getBoundingClientRect();
        const x = ((event.clientX - rect.left) / rect.width) * 100;
        const y = ((event.clientY - rect.top) / rect.height) * 100;
        heroConsole.style.setProperty('--hero-x', `${x}%`);
        heroConsole.style.setProperty('--hero-y', `${y}%`);
    });
}

document.querySelectorAll('.hero-chip').forEach((chip, index) => {
    chip.addEventListener('click', () => {
        const albumKeys = ['likes', 'charts', 'local'];
        selectMockAlbum(albumKeys[index] || 'likes');
        document.querySelectorAll('.hero-chip').forEach(item => item.classList.remove('active'));
        chip.classList.add('active');
    });
});

updateCover(getCurrentTrack());
updateProgressUI();
