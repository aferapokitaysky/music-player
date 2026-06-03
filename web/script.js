// Live simulated Web Audio spectrum visualization on canvas
const canvas = document.getElementById('visualizer-canvas');
const ctx = canvas.getContext('2d');

let animationId;
let barsCount = 28;
let frequencies = Array(barsCount).fill(0);

// Scale canvas for high-DPI displays
function resizeCanvas() {
    const dpr = window.devicePixelRatio || 1;
    canvas.width = canvas.clientWidth * dpr;
    canvas.height = canvas.clientHeight * dpr;
    ctx.scale(dpr, dpr);
}
window.addEventListener('resize', resizeCanvas);
resizeCanvas();

function drawSimulatedVisualizer() {
    const w = canvas.width / (window.devicePixelRatio || 1);
    const h = canvas.height / (window.devicePixelRatio || 1);
    
    ctx.clearRect(0, 0, w, h);
    
    // Simulate real audio frequency movements (FFT)
    frequencies = frequencies.map((f, i) => {
        const target = Math.random() * 0.9;
        return f + (target - f) * 0.12; // smooth interpolation
    });

    const spacing = 3;
    const padding = 10;
    const barWidth = (w - padding * 2 - (spacing * (barsCount - 1))) / barsCount;

    const accentColor = '#00e676';
    const subColor = '#00c853';

    for (let i = 0; i < barsCount; i++) {
        const x = padding + i * (barWidth + spacing);
        const barHeight = frequencies[i] * (h - padding * 2);
        const y = h - padding - barHeight;

        // Draw rounded frequency bars
        ctx.fillStyle = i % 2 === 0 ? accentColor : subColor;
        
        ctx.beginPath();
        if (ctx.roundRect) {
            ctx.roundRect(x, y, barWidth, barHeight, 2);
        } else {
            ctx.rect(x, y, barWidth, barHeight);
        }
        ctx.fill();
    }

    animationId = requestAnimationFrame(drawSimulatedVisualizer);
}
drawSimulatedVisualizer();

// Mockup interactive column reordering logic
let colOrder = [1, 2, 3]; // Sidebar, Tracks, Player

function shiftColumns(direction) {
    const sidebar = document.getElementById('block-sidebar');
    const tracks = document.getElementById('block-tracks');
    const player = document.getElementById('block-player');

    // Shift items in circular array order
    if (direction > 0) {
        colOrder.push(colOrder.shift());
    } else {
        colOrder.unshift(colOrder.pop());
    }

    sidebar.style.order = colOrder[0];
    tracks.style.order = colOrder[1];
    player.style.order = colOrder[2];
}

// Mockup interactive vertical component reordering logic (Player column)
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
