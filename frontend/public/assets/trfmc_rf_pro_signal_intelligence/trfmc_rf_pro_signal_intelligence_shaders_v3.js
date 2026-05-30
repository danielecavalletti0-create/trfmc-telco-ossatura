/*
 TRFMC RF PRO V3 Reality Shaders
 Local shader registry / future WebGL-WebGPU migration layer.
 No external refs.
*/

window.TRFMC_RF_PRO_V3_SHADERS = Object.freeze({
  identity_vertex_glsl: `
    attribute vec2 a_position;
    varying vec2 v_uv;
    void main(){
      v_uv = a_position * 0.5 + 0.5;
      gl_Position = vec4(a_position, 0.0, 1.0);
    }
  `,
  rf_beam_fragment_glsl: `
    precision mediump float;
    varying vec2 v_uv;
    uniform float u_time;
    void main(){
      vec2 p = v_uv - vec2(0.22,0.55);
      float beam = exp(-abs(p.y - 0.22*sin(p.x*10.0+u_time))*28.0) * smoothstep(0.0,0.8,p.x);
      vec3 col = vec3(0.0,0.85,1.0) * beam;
      gl_FragColor = vec4(col, beam);
    }
  `,
  waterfall_palette_wgsl: `
    fn rf_palette(v: f32) -> vec3<f32> {
      return vec3<f32>(0.05 + v*0.20, 0.18 + v*0.82, 0.28 + v*0.72);
    }
  `
});
