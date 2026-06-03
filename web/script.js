// State & Settings
let prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
const reducedMotionQuery = window.matchMedia('(prefers-reduced-motion: reduce)');

if (reducedMotionQuery.addEventListener) {
    reducedMotionQuery.addEventListener('change', (event) => {
        prefersReducedMotion = event.matches;
        syncParticleDensity();
    });
}

// Dummy constants to satisfy particle system formulas safely
const isPlaying = false;
const simulatedBass = 0;

// Canvas references
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

function drawParticles() {
    const width = window.innerWidth;
    const height = window.innerHeight;
    partCtx.clearRect(0, 0, width, height);
    
    const speedMultiplier = prefersReducedMotion ? 0.05 : 0.72;
    const opacityMultiplier = 0.38;
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
        partCtx.arc(p.x, p.y, p.size, 0, Math.PI * 2);
        partCtx.fill();

        if (!prefersReducedMotion) {
            for (let j = i + 1; j < particles.length; j++) {
                const n = particles[j];
                const dx = p.x - n.x;
                const dy = p.y - n.y;
                const distance = Math.hypot(dx, dy);
                if (distance < 84) {
                    partCtx.globalAlpha = (1 - distance / 84) * 0.03;
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
const interactiveElements = 'a, button, [onclick], .hero-chip, input, details';
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


// --- SCREENSHOT 3D PERSPECTIVE TILT ANIMATION ---
const screenshotFrame = document.getElementById('screenshot-frame');
if (screenshotFrame) {
    screenshotFrame.addEventListener('mousemove', (e) => {
        if (prefersReducedMotion) return;
        const rect = screenshotFrame.getBoundingClientRect();
        const x = e.clientX - rect.left;
        const y = e.clientY - rect.top;
        
        // Calculate tilt percentages relative to center
        const centerX = rect.width / 2;
        const centerY = rect.height / 2;
        const rotateX = ((centerY - y) / centerY) * 10; // Max 10 degrees tilt
        const rotateY = ((x - centerX) / centerX) * 10;
        
        screenshotFrame.style.transform = `perspective(1200px) rotateX(${rotateX}deg) rotateY(${rotateY}deg) scale3d(1.02, 1.02, 1.02)`;
        
        // Adjust liquid highlight coordinate variables
        screenshotFrame.style.setProperty('--mouse-x', `${x}px`);
        screenshotFrame.style.setProperty('--mouse-y', `${y}px`);
    });
    
    screenshotFrame.addEventListener('mouseleave', () => {
        screenshotFrame.style.transform = 'perspective(1200px) rotateX(0deg) rotateY(0deg) scale3d(1, 1, 1)';
        screenshotFrame.style.setProperty('--mouse-x', '50%');
        screenshotFrame.style.setProperty('--mouse-y', '50%');
    });
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
        if (prefersReducedMotion) return;
        const rect = heroConsole.getBoundingClientRect();
        const x = ((event.clientX - rect.left) / rect.width) * 100;
        const y = ((event.clientY - rect.top) / rect.height) * 100;
        heroConsole.style.setProperty('--hero-x', `${x}%`);
        heroConsole.style.setProperty('--hero-y', `${y}%`);
    });
}

document.querySelectorAll('.hero-chip').forEach((chip) => {
    chip.addEventListener('click', () => {
        document.querySelectorAll('.hero-chip').forEach(item => item.classList.remove('active'));
        chip.classList.add('active');
    });
});

// --- DYNAMIC AMBIENT GLOW FOLLOW ---
const glowCyan = document.querySelector('.ambient-glow.cyan');
const glowOrange = document.querySelector('.ambient-glow.orange');
let targetGlowX = window.innerWidth / 2;
let targetGlowY = window.innerHeight / 2;
let currentGlowX = window.innerWidth / 2;
let currentGlowY = window.innerHeight / 2;

window.addEventListener('mousemove', (e) => {
    targetGlowX = e.clientX;
    targetGlowY = e.clientY;
});

function tickGlows() {
    if (prefersReducedMotion) return;
    currentGlowX += (targetGlowX - currentGlowX) * 0.03;
    currentGlowY += (targetGlowY - currentGlowY) * 0.03;
    
    if (glowCyan) {
        glowCyan.style.transform = `translate3d(${currentGlowX * 0.12}px, ${currentGlowY * 0.12}px, 0)`;
    }
    if (glowOrange) {
        glowOrange.style.transform = `translate3d(${-currentGlowX * 0.08}px, ${-currentGlowY * 0.08}px, 0)`;
    }
    requestAnimationFrame(tickGlows);
}
tickGlows();
