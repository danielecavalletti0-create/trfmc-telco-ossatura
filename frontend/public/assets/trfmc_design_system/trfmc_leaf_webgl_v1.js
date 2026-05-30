(function(){
  function boot(){
    const canvases=document.querySelectorAll('[data-trfmc-webgl]');
    canvases.forEach((canvas,idx)=>init(canvas,idx));
  }
  function init(canvas,idx){
    const gl=canvas.getContext('webgl',{antialias:true,alpha:false});
    const state=document.querySelector('[data-gl-state]');
    if(!gl){ if(state) state.textContent='fallback'; return; }
    if(state) state.textContent='webgl';

    const vs='attribute vec2 p; varying vec2 v; void main(){v=p; gl_Position=vec4(p,0.0,1.0);}';
    const fs='precision mediump float; varying vec2 v; uniform float t; uniform vec2 r; uniform float mode; float line(vec2 p, vec2 a, vec2 b){vec2 pa=p-a, ba=b-a; float h=clamp(dot(pa,ba)/dot(ba,ba),0.0,1.0); return length(pa-ba*h);} void main(){vec2 uv=(v+1.0)*0.5; vec2 p=uv*2.0-1.0; p.x*=r.x/r.y; float g=0.0; for(int i=0;i<8;i++){float fi=float(i); vec2 a=vec2(sin(t*.20+fi+mode)*.72,cos(t*.17+fi*1.71)*.48); vec2 b=vec2(cos(t*.19+fi*1.3)*.82,sin(t*.23+fi*.9+mode)*.52); float d=line(p,a,b); g+=0.006/(d+0.006);} float rings=abs(sin(18.0*length(p)-t*1.8))*0.035/(abs(length(p)-0.44)+0.035); float grid=(step(.986,fract(uv.x*32.0))+step(.986,fract(uv.y*18.0)))*.08; vec3 col=vec3(0.004,0.017,0.028); col+=vec3(0.0,0.70,1.0)*g*.30; col+=vec3(0.45,1.0,0.25)*grid; col+=vec3(0.35,0.15,1.0)*rings; col+=vec3(0.0,0.16,0.22)*(1.0-length(p)*.45); gl_FragColor=vec4(col,1.0);}';

    function compile(type,src){
      const s=gl.createShader(type);
      gl.shaderSource(s,src);
      gl.compileShader(s);
      return s;
    }

    const pr=gl.createProgram();
    gl.attachShader(pr,compile(gl.VERTEX_SHADER,vs));
    gl.attachShader(pr,compile(gl.FRAGMENT_SHADER,fs));
    gl.linkProgram(pr);
    gl.useProgram(pr);

    const buf=gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER,buf);
    gl.bufferData(gl.ARRAY_BUFFER,new Float32Array([-1,-1,1,-1,-1,1,1,1]),gl.STATIC_DRAW);
    const loc=gl.getAttribLocation(pr,'p');
    gl.enableVertexAttribArray(loc);
    gl.vertexAttribPointer(loc,2,gl.FLOAT,false,0,0);

    const ut=gl.getUniformLocation(pr,'t');
    const ur=gl.getUniformLocation(pr,'r');
    const um=gl.getUniformLocation(pr,'mode');

    function frame(ms){
      const dpr=window.devicePixelRatio||1;
      const w=canvas.clientWidth*dpr|0;
      const h=canvas.clientHeight*dpr|0;
      if(canvas.width!==w||canvas.height!==h){
        canvas.width=w; canvas.height=h; gl.viewport(0,0,w,h);
      }
      gl.uniform1f(ut,ms*.001);
      gl.uniform2f(ur,canvas.width,canvas.height);
      gl.uniform1f(um,idx+1.0);
      gl.drawArrays(gl.TRIANGLE_STRIP,0,4);
      requestAnimationFrame(frame);
    }
    requestAnimationFrame(frame);
  }
  if(document.readyState==='loading') document.addEventListener('DOMContentLoaded',boot);
  else boot();
})();
