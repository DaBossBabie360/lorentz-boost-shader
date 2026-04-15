# Lorentz Boost Grid

A real-time GLSL shader that visualizes relativistic length contraction by ray-tracing a 3D wireframe grid through a Lorentz transformation.

[**View on Shadertoy**](https://www.shadertoy.com/view/tcGcRR)

## What It Does

A camera orbits a 3D wireframe grid while a Lorentz boost oscillates along the X-axis. As the rapidity parameter increases, the grid visibly contracts along the direction of motion, the same length contraction predicted by special relativity. The grid lines also glow brighter at higher boost speeds, simulating a time-dilation-inspired color shift.

## How It Works

The shader casts a ray from the camera through each pixel and analytically solves for intersections with a Lorentz-transformed grid. There's no mesh, no rasterization, everything is computed per-pixel from the math.

**The pipeline:**

1. **Lorentz transformation**, A 4x4 boost matrix (parameterized by rapidity `phi`, where `tanh(phi) = v/c`) transforms the ray origin and direction into the boosted reference frame.

2. **Analytical grid intersection**, For each spatial axis in the primed frame, the shader solves the linear equation `A' * t + B' = n * spacing` for nearby integer grid planes, then checks whether the hit point falls on a grid line in the other two dimensions.

3. **Phong shading**, Hits are lit with ambient + Lambertian diffuse + specular reflection. A fog falloff prevents far grid lines from dominating.

4. **Relativistic color effect**, The magnitude of the boost (`|phi|`) scales ambient brightness, giving a visual cue for how fast the frame is moving.

## The Math

The Lorentz boost matrix for velocity along the X-axis is:

```
Λ = | cosh(φ)  -sinh(φ)   0   0 |
    | -sinh(φ)  cosh(φ)   0   0 |
    |    0         0       1   0 |
    |    0         0       0   1 |
```

where `φ` is the rapidity (`tanh(φ) = v/c`). `cosh(φ)` is the Lorentz factor γ, and `sinh(φ) = γv/c`. The Y and Z axes are unchanged, only time and the axis of motion mix.

A 4D spacetime point on the ray is `X(t) = (t_observer, ro + t · rd)`. Transforming: `X'(t) = Λ · X(t)`. Since this is linear in `t`, we get `X'(t) = B' + t · A'` where `B' = Λ · ro4` and `A' = Λ · rd4`, making plane intersections a simple division.

## Parameters

| Define | Default | Description |
|--------|---------|-------------|
| `GRID_SPACING` | 2.0 | Distance between grid lines in the boosted frame |
| `RAPIDITY_SPEED` | 0.3 | How fast the boost oscillates |
| `COLOR_SHIFT_MAG` | 2.0 | Strength of the time-dilation color glow |
| `LINE_THICKNESS` | 0.05 | Width of grid lines |

## Running It

Just chuck `lorentz-grid.glsl` into [Shadertoy](https://www.shadertoy.com/new) and hit play.

Alternatively, any GLSL sandbox that provides `iResolution`, `iTime`, and a `mainImage` entry point will work (e.g., glslsandbox, bonzomatic, or a custom OpenGL/Vulkan setup).
