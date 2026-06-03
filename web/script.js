// Global variables for Player state
let isPlaying = false;
let currentVisualizerMode = 'bars'; // bars, wave, circle, dots
let trackProgress = 35; // percentage
let playProgressInterval;

// Track library database
const mockAlbums = {
    likes: [
        { title: "Я устал", artist: "1.Kla$" },
        { title: "INNA - Love", artist: "INNA" },
        { title: "Мармелад", artist: "Катя Лель" }
    ],
    charts: [
        { title: "Gimme! Gimme! Gimme!", artist: "ABBA" },
        { title: "Du Hast", artist: "Rammstein" },
        { title: "Toxic", artist: "Britney Spears" }
    ],
    local: [
        { title: "Tea & Chill", artist: "Lofi Beats" },
        { title: "Sunset Drive", artist: "Synthwave Producer" },
        { title: "Rainy Cafe", artist: "Acoustic Duo" }
    ]
};
let currentPlaylist = 'likes';
let currentTrackIndex = 0;

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
const particleCount = 65;

function initParticles() {
    particles = [];
    const colors = ['#ffffff', '#b3b3b3', '#737373'];
    for (let i = 0; i < particleCount; i++) {
        particles.push({
            x: Math.random() * window.innerWidth,
            y: Math.random() * window.innerHeight,
            vx: (Math.random() - 0.5) * 0.35,
            vy: (Math.random() - 0.5) * 0.35,
            size: Math.random() * 2.2 + 0.6,
            opacity: Math.random() * 0.4 + 0.1,
            color: colors[Math.floor(Math.random() * colors.length)]
        });
    }
}

function resizeParticlesCanvas() {
    partCanvas.width = window.innerWidth;
    partCanvas.height = window.innerHeight;
}
window.addEventListener('resize', () => {
    resizeParticlesCanvas();
    resizeVisCanvas();
});
resizeParticlesCanvas();
initParticles();

// Simulate bass beat peak
let simulatedBass = 0;

function drawParticles() {
    partCtx.clearRect(0, 0, partCanvas.width, partCanvas.height);
    
    // speed multiplier increases if playing and based on bass frequency peaks
    const speedMultiplier = 1.0 + (isPlaying ? simulatedBass * 8.0 : 0.0);
    const opacityMultiplier = isPlaying ? (0.6 + simulatedBass * 0.4) : 0.4;
    const padding = 20;

    for (let i = 0; i < particles.length; i++) {
        const p = particles[i];
        
        // Move particle
        p.x += p.vx * speedMultiplier;
        p.y += p.vy * speedMultiplier;

        // Wrap boundaries
        if (p.x < -padding) p.x = partCanvas.width + padding;
        else if (p.x > partCanvas.width + padding) p.x = -padding;

        if (p.y < -padding) p.y = partCanvas.height + padding;
        else if (p.y > partCanvas.height + padding) p.y = -padding;

        // Draw particle
        partCtx.fillStyle = p.color;
        partCtx.globalAlpha = p.opacity * opacityMultiplier;
        partCtx.beginPath();
        partCtx.arc(p.x, p.y, p.size, 0, Math.PI * 2);
        partCtx.fill();
    }
    partCtx.globalAlpha = 1.0;
    requestAnimationFrame(drawParticles);
}
drawParticles();


// --- VISUALIZER DRAW LOOP ---
function resizeVisCanvas() {
    const dpr = window.devicePixelRatio || 1;
    visCanvas.width = visCanvas.clientWidth * dpr;
    visCanvas.height = visCanvas.clientHeight * dpr;
    visCtx.scale(dpr, dpr);
}
resizeVisCanvas();

function setVisualizerMode(mode) {
    currentVisualizerMode = mode;
    document.querySelectorAll('.vis-tab').forEach(tab => {
        tab.classList.remove('active');
    });
    const btn = document.getElementById(`btn-vis-${mode}`);
    if (btn) btn.classList.add('active');
}

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
    const playBtn = document.getElementById('play-pause-toggle');
    if (isPlaying) {
        playBtn.innerText = '⏸';
        playProgressInterval = setInterval(() => {
            trackProgress = (trackProgress + 0.4) % 100;
            document.getElementById('track-progress').style.width = `${trackProgress}%`;
        }, 100);
    } else {
        playBtn.innerText = '▶';
        clearInterval(playProgressInterval);
    }
}

function playMockTrack(title, artist) {
    document.getElementById('nowplaying-title').innerText = title;
    document.getElementById('nowplaying-artist').innerText = artist;
    
    // Reset track progress
    trackProgress = 0;
    document.getElementById('track-progress').style.width = '0%';
    
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

    // Update track list container
    const tracksContainer = document.getElementById('mock-tracks-container');
    tracksContainer.innerHTML = '';
    
    mockAlbums[albumKey].forEach((track, index) => {
        const item = document.createElement('div');
        item.className = 'mock-track' + (index === 0 ? ' active' : '');
        item.onclick = () => {
            currentTrackIndex = index;
            document.querySelectorAll('.mock-track').forEach(el => el.classList.remove('active'));
            item.classList.add('active');
            playMockTrack(track.title, track.artist);
        };
        
        // Generate nice dummy times
        const times = ["3:25", "3:24", "2:02", "4:15", "3:10"];
        const time = times[index % times.length];
        
        item.innerHTML = `<span>${track.title}</span><span class="time">${time}</span>`;
        tracksContainer.appendChild(item);
    });

    // Play first track of selected album
    const first = mockAlbums[albumKey][0];
    playMockTrack(first.title, first.artist);
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
    
    // Update visual selector in tracks list
    const tracksElements = document.querySelectorAll('.mock-track');
    tracksElements.forEach(el => el.classList.remove('active'));
    if (tracksElements[currentTrackIndex]) {
        tracksElements[currentTrackIndex].classList.add('active');
    }
    
    playMockTrack(track.title, track.artist);
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
                <div class="track-row" onclick="playMockTrack('Я устал', '1.Kla$'); closeSearchOverlay()">
                    <span class="mini-play">▶</span>
                    <div>
                        <span class="track-name">Я устал</span>
                        <span class="track-artist">1.Kla$</span>
                    </div>
                </div>
                <div class="track-row" onclick="playMockTrack('INNA - Love', 'INNA'); closeSearchOverlay()">
                    <span class="mini-play">▶</span>
                    <div>
                        <span class="track-name">INNA - Love</span>
                        <span class="track-artist">INNA</span>
                    </div>
                </div>
            </div>
        `;
        return;
    }

    // Filter track search simulator
    const allTracks = [
        { title: "Я устал", artist: "1.Kla$" },
        { title: "INNA - Love", artist: "INNA" },
        { title: "Мармелад", artist: "Катя Лель" },
        { title: "Gimme! Gimme! Gimme!", artist: "ABBA" },
        { title: "Du Hast", artist: "Rammstein" },
        { title: "Toxic", artist: "Britney Spears" },
        { title: "Tea & Chill", artist: "Lofi Beats" },
        { title: "Sunset Drive", artist: "Synthwave Producer" }
    ];

    const results = allTracks.filter(t => t.title.toLowerCase().includes(query) || t.artist.toLowerCase().includes(query));

    let html = `<div class="section-title">РЕЗУЛЬТАТЫ ПОИСКА (${currentSearchSource.toUpperCase()})</div>`;
    if (results.length === 0) {
        html += `<div style="color: var(--text-tertiary); font-size:12px; padding:10px;">Ничего не найдено</div>`;
    } else {
        results.forEach(track => {
            html += `
                <div class="track-row" onclick="playMockTrack('${track.title}', '${track.artist}'); closeSearchOverlay()">
                    <span class="mini-play">▶</span>
                    <div>
                        <span class="track-name">${track.title}</span>
                        <span class="track-artist">${track.artist}</span>
                    </div>
                </div>
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
    const btn = document.querySelector('.theme-toggle-btn');
    btn.innerText = `🎨 Тема: ${themes[currentThemeIndex]}`;
    
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
    }
}
