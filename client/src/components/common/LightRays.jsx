import { useRef, useEffect, useState } from 'react'
import { Renderer, Program, Triangle, Mesh } from 'ogl'
import './LightRays.css'

const LightRays = ({
  raysOrigin = 'bottom-center',
  raysSpeed = 0.4,
  lightSpread = 0.2,
  rayLength = 1.3,
  fadeDistance = 1.2,
  saturation = 0.9,
  mouseInfluence = 0.4,
  noiseAmount = 0,
  distortion = 0,
  pulsating = false,
  raysColor = 'rgba(6, 182, 212, 1.0)',
}) => {
  const containerRef = useRef(null)
  const rendererRef = useRef(null)
  const programRef = useRef(null)
  const meshRef = useRef(null)
  const animationRef = useRef(null)
  const mouseRef = useRef({ x: 0.5, y: 0.5 })
  const timeRef = useRef(0)

  // Parse origin to coordinates
  const getOriginCoords = () => {
    const origins = {
      'top': [0.5, 1.0],
      'top-left': [0.0, 1.0],
      'top-right': [1.0, 1.0],
      'bottom': [0.5, 0.0],
      'bottom-center': [0.5, 0.0],
      'bottom-left': [0.0, 0.0],
      'bottom-right': [1.0, 0.0],
      'left': [0.0, 0.5],
      'right': [1.0, 0.5],
      'center': [0.5, 0.5],
    }
    return origins[raysOrigin] || [0.5, 0.0]
  }

  // Parse color to vec3
  const parseColor = (color) => {
    const rgba = color.match(/rgba?\((\d+),\s*(\d+),\s*(\d+)/i)
    if (rgba) {
      return [
        parseInt(rgba[1]) / 255,
        parseInt(rgba[2]) / 255,
        parseInt(rgba[3]) / 255,
      ]
    }
    return [0.024, 0.714, 0.831] // Default cyan
  }

  useEffect(() => {
    if (!containerRef.current) return

    // Create renderer
    const renderer = new Renderer({
      width: containerRef.current.offsetWidth,
      height: containerRef.current.offsetHeight,
      dpr: Math.min(window.devicePixelRatio, 2),
      alpha: true,
    })
    const gl = renderer.gl
    containerRef.current.appendChild(gl.canvas)
    rendererRef.current = renderer

    // Vertex shader
    const vertex = /* glsl */ `
      attribute vec2 position;
      attribute vec2 uv;
      varying vec2 vUv;
      void main() {
        vUv = uv;
        gl_Position = vec4(position, 0.0, 1.0);
      }
    `

    // Fragment shader with volumetric light rays
    const fragment = /* glsl */ `
      precision highp float;
      uniform float uTime;
      uniform vec2 uResolution;
      uniform vec2 uRaysOrigin;
      uniform vec2 uMouse;
      uniform float uRaysSpeed;
      uniform float uLightSpread;
      uniform float uRayLength;
      uniform float uFadeDistance;
      uniform float uSaturation;
      uniform float uMouseInfluence;
      uniform float uNoiseAmount;
      uniform float uDistortion;
      uniform float uPulsating;
      uniform vec3 uRaysColor;
      varying vec2 vUv;

      // Noise function
      float noise(vec2 st) {
        return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
      }

      float fbm(vec2 st) {
        float value = 0.0;
        float amplitude = 0.5;
        float frequency = 1.0;
        for (int i = 0; i < 4; i++) {
          value += amplitude * noise(st * frequency);
          frequency *= 2.0;
          amplitude *= 0.5;
        }
        return value;
      }

      void main() {
        vec2 uv = vUv;
        vec2 st = uv * 2.0 - 1.0;
        st.x *= uResolution.x / uResolution.y;

        // Adjust origin based on aspect ratio
        vec2 origin = uRaysOrigin * 2.0 - 1.0;
        origin.x *= uResolution.x / uResolution.y;

        // Apply mouse influence to origin
        vec2 mouseOffset = (uMouse - 0.5) * uMouseInfluence;
        origin += mouseOffset;

        // Calculate direction from origin to current pixel
        vec2 dir = st - origin;
        float dist = length(dir);
        dir = normalize(dir);

        // Calculate angle for ray pattern
        float angle = atan(dir.y, dir.x);

        // Create rotating ray pattern
        float rayPattern = 0.0;
        const float numRays = 12.0;
        float rayTime = uTime * uRaysSpeed;

        for (float i = 0.0; i < numRays; i++) {
          float rayAngle = (i / numRays) * 6.28318 + rayTime;
          float angleDiff = abs(mod(angle - rayAngle + 3.14159, 6.28318) - 3.14159);

          // Add noise to rays if enabled
          float noiseVal = 1.0;
          if (uNoiseAmount > 0.0) {
            noiseVal = fbm(dir * 3.0 + uTime * 0.1) * uNoiseAmount + (1.0 - uNoiseAmount);
          }

          float rayWidth = uLightSpread * noiseVal;
          float ray = smoothstep(rayWidth, 0.0, angleDiff);

          // Add distortion if enabled
          if (uDistortion > 0.0) {
            float distortNoise = fbm(st * 2.0 + uTime * 0.2);
            ray *= (1.0 - uDistortion) + distortNoise * uDistortion;
          }

          rayPattern += ray;
        }

        rayPattern = clamp(rayPattern, 0.0, 1.0);

        // Distance-based fade
        float fade = 1.0 - smoothstep(0.0, uFadeDistance, dist);

        // Ray length control
        float lengthMask = smoothstep(uRayLength, uRayLength * 0.5, dist);

        // Pulsating effect
        float pulse = 1.0;
        if (uPulsating > 0.5) {
          pulse = 0.7 + 0.3 * sin(uTime * 2.0);
        }

        // Combine all effects
        float intensity = rayPattern * fade * lengthMask * pulse;

        // Apply saturation to color
        vec3 finalColor = uRaysColor * uSaturation;

        // Output with alpha - increased visibility
        gl_FragColor = vec4(finalColor, intensity * 0.95);
      }
    `

    // Create program
    const program = new Program(gl, {
      vertex,
      fragment,
      uniforms: {
        uTime: { value: 0 },
        uResolution: { value: [containerRef.current.offsetWidth, containerRef.current.offsetHeight] },
        uRaysOrigin: { value: getOriginCoords() },
        uMouse: { value: [0.5, 0.5] },
        uRaysSpeed: { value: raysSpeed },
        uLightSpread: { value: lightSpread },
        uRayLength: { value: rayLength },
        uFadeDistance: { value: fadeDistance },
        uSaturation: { value: saturation },
        uMouseInfluence: { value: mouseInfluence },
        uNoiseAmount: { value: noiseAmount },
        uDistortion: { value: distortion },
        uPulsating: { value: pulsating ? 1.0 : 0.0 },
        uRaysColor: { value: parseColor(raysColor) },
      },
      transparent: true,
    })
    programRef.current = program

    // Create geometry (fullscreen triangle)
    const geometry = new Triangle(gl)

    const mesh = new Mesh(gl, { geometry, program })
    meshRef.current = mesh

    // Handle mouse movement
    const handleMouseMove = (e) => {
      const rect = containerRef.current.getBoundingClientRect()
      mouseRef.current = {
        x: (e.clientX - rect.left) / rect.width,
        y: 1.0 - (e.clientY - rect.top) / rect.height,
      }
    }

    // Handle resize
    const handleResize = () => {
      if (!containerRef.current) return
      const width = containerRef.current.offsetWidth
      const height = containerRef.current.offsetHeight
      renderer.setSize(width, height)
      program.uniforms.uResolution.value = [width, height]
    }

    window.addEventListener('mousemove', handleMouseMove)
    window.addEventListener('resize', handleResize)

    // Animation loop
    const animate = (t) => {
      timeRef.current = t * 0.001 // Convert to seconds

      program.uniforms.uTime.value = timeRef.current
      program.uniforms.uMouse.value = [mouseRef.current.x, mouseRef.current.y]

      renderer.render({ scene: mesh })
      animationRef.current = requestAnimationFrame(animate)
    }
    animationRef.current = requestAnimationFrame(animate)

    // Cleanup
    return () => {
      window.removeEventListener('mousemove', handleMouseMove)
      window.removeEventListener('resize', handleResize)
      if (animationRef.current) {
        cancelAnimationFrame(animationRef.current)
      }
      if (gl.canvas && containerRef.current?.contains(gl.canvas)) {
        containerRef.current.removeChild(gl.canvas)
      }
    }
  }, [
    raysOrigin,
    raysSpeed,
    lightSpread,
    rayLength,
    fadeDistance,
    saturation,
    mouseInfluence,
    noiseAmount,
    distortion,
    pulsating,
    raysColor,
  ])

  return <div ref={containerRef} className="light-rays-container" />
}

export default LightRays
