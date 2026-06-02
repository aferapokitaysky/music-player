<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { get } from 'svelte/store';
  import { VisualizerMode, ThemePalette } from '../types';
  import { visualizerBars, isPlaying } from '../playerStore';

  export let mode: VisualizerMode;
  export let palette: ThemePalette;

  let canvas: HTMLCanvasElement;
  let ctx: CanvasRenderingContext2D | null = null;
  let animationFrameId: number;

  onMount(() => {
    ctx = canvas.getContext('2d');
    renderLoop();
  });

  onDestroy(() => {
    cancelAnimationFrame(animationFrameId);
  });

  function renderLoop() {
    if (!ctx || !canvas) return;
    const w = canvas.width;
    const h = canvas.height;
    ctx.clearRect(0, 0, w, h);

    const bars = get(visualizerBars);

    if (mode === 'bars') {
      drawBars(ctx, w, h, bars);
    } else if (mode === 'wave') {
      drawWave(ctx, w, h, bars);
    } else if (mode === 'circle') {
      drawCircle(ctx, w, h, bars);
    } else if (mode === 'dots') {
      drawDots(ctx, w, h, bars);
    }

    animationFrameId = requestAnimationFrame(renderLoop);
  }

  function drawBars(ctx: CanvasRenderingContext2D, w: number, h: number, bars: number[]) {
    const n = bars.length;
    const cellCount = 14;
    const hPad = 14;
    const vPad = 14;
    const spacing = 3;
    const cellGap = 2;

    const totalSpacing = spacing * (n - 1);
    const barWidth = Math.max(2, (w - totalSpacing - hPad * 2) / n);
    const cellHeight = Math.max(1, (h - vPad * 2 - cellGap * (cellCount - 1)) / cellCount);

    for (let i = 0; i < n; i++) {
      const x = hPad + i * (barWidth + spacing);
      const activeCells = Math.floor(bars[i] * cellCount);

      for (let c = 0; c < cellCount; c++) {
        const cellIndex = (cellCount - 1) - c; // 0 = bottom
        const isActive = cellIndex < activeCells;
        const y = vPad + c * (cellHeight + cellGap);

        ctx.fillStyle = isActive 
          ? (cellIndex > 9 ? palette.accent : palette.accentSecondary)
          : 'rgba(255, 255, 255, 0.04)';
        
        // Draw rounded cell rects
        drawRoundRect(ctx, x, y, barWidth, cellHeight, 1.5);
      }
    }
  }

  function drawWave(ctx: CanvasRenderingContext2D, w: number, h: number, bars: number[]) {
    const midY = h / 2;
    const step = w / (bars.length - 1);
    const time = Date.now() * 0.002;

    const drawSingleWave = (phaseOffset: number, color: string, width: number, opacity: number) => {
      ctx.beginPath();
      ctx.lineWidth = width;
      ctx.strokeStyle = color;
      ctx.globalAlpha = opacity;

      for (let i = 0; i < bars.length; i++) {
        const x = i * step;
        const barVal = bars[i];
        const sineFactor = Math.sin(i * 0.4 + phaseOffset + time * 1.1);
        const y = midY + barVal * (h / 2.2) * sineFactor;

        if (i === 0) {
          ctx.moveTo(x, y);
        } else {
          ctx.lineTo(x, y);
        }
      }
      ctx.stroke();
      ctx.globalAlpha = 1.0;
    };

    // Draw multi-layered glow wave
    drawSingleWave(0, palette.accent, 6, 0.16);
    drawSingleWave(Math.PI * 0.5, palette.accentSecondary, 4, 0.42);
    drawSingleWave(Math.PI * 1.1, palette.textPrimary, 2, 0.95);
  }

  function drawCircle(ctx: CanvasRenderingContext2D, w: number, h: number, bars: number[]) {
    const center = { x: w / 2, y: h / 2 };
    const maxRadius = Math.min(w, h) / 2.3;
    const minRadius = maxRadius * 0.4;
    const n = bars.length;

    // Center ambient circle
    ctx.beginPath();
    ctx.arc(center.x, center.y, minRadius, 0, Math.PI * 2);
    ctx.fillStyle = palette.accent + '0A'; // 4% opacity
    ctx.fill();
    ctx.lineWidth = 1;
    ctx.strokeStyle = palette.accent + '26'; // 15% opacity
    ctx.stroke();

    const angleStep = (2 * Math.PI) / n;
    for (let i = 0; i < n; i++) {
      const angle = i * angleStep;
      const barVal = bars[i];
      const startX = center.x + Math.cos(angle) * minRadius;
      const startY = center.y + Math.sin(angle) * minRadius;

      const length = (maxRadius - minRadius) * barVal;
      const endX = center.x + Math.cos(angle) * (minRadius + Math.max(2, length));
      const endY = center.y + Math.sin(angle) * (minRadius + Math.max(2, length));

      ctx.beginPath();
      ctx.moveTo(startX, startY);
      ctx.lineTo(endX, endY);
      ctx.lineWidth = 2;
      ctx.strokeStyle = palette.accent;
      ctx.globalAlpha = 0.4 + barVal * 0.6;
      ctx.stroke();
    }
    ctx.globalAlpha = 1.0;
  }

  function drawDots(ctx: CanvasRenderingContext2D, w: number, h: number, bars: number[]) {
    const n = bars.length;
    const dotsPerColumn = 10;
    const hPad = 14;
    const vPad = 14;
    const spacing = 4;
    const dotGap = 3;

    const totalSpacing = spacing * (n - 1);
    const colWidth = Math.max(2, (w - totalSpacing - hPad * 2) / n);
    const dotHeight = Math.max(2, (h - vPad * 2 - dotGap * (dotsPerColumn - 1)) / dotsPerColumn);
    const dotSize = Math.min(colWidth, dotHeight);

    for (let i = 0; i < n; i++) {
      const x = hPad + i * (colWidth + spacing) + (colWidth - dotSize) / 2;
      const activeDots = Math.floor(bars[i] * dotsPerColumn);

      for (let d = 0; d < dotsPerColumn; d++) {
        const dotIndex = (dotsPerColumn - 1) - d;
        const isActive = dotIndex < activeDots;
        const y = vPad + d * (dotSize + dotGap) + (dotHeight - dotSize) / 2;

        ctx.fillStyle = isActive 
          ? palette.accent 
          : 'rgba(255, 255, 255, 0.04)';
        
        ctx.beginPath();
        ctx.arc(x + dotSize / 2, y + dotSize / 2, dotSize / 2, 0, Math.PI * 2);
        ctx.fill();
      }
    }
  }

  function drawRoundRect(ctx: CanvasRenderingContext2D, x: number, y: number, w: number, h: number, r: number) {
    ctx.beginPath();
    ctx.moveTo(x + r, y);
    ctx.lineTo(x + w - r, y);
    ctx.quadraticCurveTo(x + w, y, x + w, y + r);
    ctx.lineTo(x + w, y + h - r);
    ctx.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
    ctx.lineTo(x + r, y + h);
    ctx.quadraticCurveTo(x, y + h, x, y + h - r);
    ctx.lineTo(x, y + r);
    ctx.quadraticCurveTo(x, y, x + r, y);
    ctx.closePath();
    ctx.fill();
  }
</script>

<canvas bind:this={canvas} width="400" height="150" class="w-full h-[130px] rounded-2xl"></canvas>

<style>
  canvas {
    display: block;
  }
</style>
