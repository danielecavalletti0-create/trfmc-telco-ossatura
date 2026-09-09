(function(){
  const sites=[
    {x:-0.58,y:-0.20,p:1.05,c:[0.25,1.0,0.45]},
    {x:0.48,y:-0.05,p:0.92,c:[0.20,0.82,1.0]},
    {x:0.02,y:0.48,p:0.78,c:[1.0,0.75,0.18]}
  ];
  let gl,program,buf,loc={},start=performance.now(),frames=0,last=performance.now();
  let showUE=true,showHeat=true,power=1,noise=.12,speed=1.2,scenario="urban";
  const ue=Array.from({length:24},(_,i)=>({a:Math.random()*6.28,r:.18+Math.random()*.68,o:i*.27}));

  function shader(type,src){const s=gl.createShader(type);gl.shaderSource(s,src);gl.compileShader(s);if(!gl.getShaderParameter(s,gl.COMPILE_STATUS))throw gl.getShaderInfoLog(s);return s;}
  function init(){
    const canvas=document.getElementById("v66_canvas");
    gl=canvas.getContext("webgl",{antialias:true,preserveDrawingBuffer:false});
    if(!gl){document.getElementById("v66_state").textContent="WEBGL UNAVAILABLE";return;}
    const vs=`attribute vec2 p; varying vec2 v; void main(){v=p; gl_Position=vec4(p,0.0,1.0);}`;
    const fs=`precision highp float;
      varying vec2 v; uniform float t; uniform float power; uniform float noise; uniform float heat; uniform float scen;
      float site(vec2 p, vec2 s, float pw, float az){
        vec2 d=p-s; float r=length(d); float a=atan(d.y,d.x);
        float beam=pow(max(0.0,cos(a-az)),6.0);
        float fspl=pw/(0.045+r*r*2.2);
        float clutter=1.0;
        clutter-=0.28*smoothstep(.05,.22,abs(p.x+.18))*smoothstep(.08,.42,p.y+.10);
        clutter-=0.18*smoothstep(.02,.18,abs(p.x-.25))*smoothstep(.0,.55,p.y+.35);
        return fspl*(.32+.88*beam)*clutter;
      }
      vec3 ramp(float x){
        x=clamp(x,0.0,1.0);
        vec3 a=vec3(.02,.05,.20), b=vec3(.0,.55,1.0), c=vec3(.12,1.0,.38), d=vec3(1.0,.72,.12), e=vec3(1.0,.08,.30);
        if(x<.25)return mix(a,b,x/.25);
        if(x<.52)return mix(b,c,(x-.25)/.27);
        if(x<.78)return mix(c,d,(x-.52)/.26);
        return mix(d,e,(x-.78)/.22);
      }
      void main(){
        vec2 p=v; float grid=(step(.985,cos((p.x+t*.02)*70.0))*0.03)+(step(.988,cos((p.y-t*.015)*70.0))*0.03);
        float f=0.0;
        f+=site(p,vec2(-.58,-.20),1.05*power,.10);
        f+=site(p,vec2(.48,-.05),.92*power,3.05);
        f+=site(p,vec2(.02,.48),.78*power,-1.55);
        f-=noise*(.25+.75*fract(sin(dot(p+t*.01,vec2(12.9898,78.233)))*43758.5453));
        f*=heat;
        vec3 col=ramp(f*.72);
        col+=grid*vec3(.2,.9,1.0);
        float vign=1.0-smoothstep(.55,1.25,length(p));
        col*=.42+.78*vign;
        gl_FragColor=vec4(col,1.0);
      }`;
    program=gl.createProgram();gl.attachShader(program,shader(gl.VERTEX_SHADER,vs));gl.attachShader(program,shader(gl.FRAGMENT_SHADER,fs));gl.linkProgram(program);
    if(!gl.getProgramParameter(program,gl.LINK_STATUS))throw gl.getProgramInfoLog(program);
    gl.useProgram(program);
    buf=gl.createBuffer();gl.bindBuffer(gl.ARRAY_BUFFER,buf);gl.bufferData(gl.ARRAY_BUFFER,new Float32Array([-1,-1,1,-1,-1,1,1,1]),gl.STATIC_DRAW);
    const p=gl.getAttribLocation(program,"p");gl.enableVertexAttribArray(p);gl.vertexAttribPointer(p,2,gl.FLOAT,false,0,0);
    ["t","power","noise","heat","scen"].forEach(k=>loc[k]=gl.getUniformLocation(program,k));
    document.getElementById("v66_renderer").textContent=gl.getParameter(gl.RENDERER).slice(0,24);
    document.getElementById("v66_state").textContent="GPU ENGINE READY";
    bind();
    requestAnimationFrame(loop);
  }
  function bind(){
    const $=id=>document.getElementById(id);
    $("v66_power").oninput=e=>power=parseFloat(e.target.value);
    $("v66_noise").oninput=e=>noise=parseFloat(e.target.value);
    $("v66_speed").oninput=e=>speed=parseFloat(e.target.value);
    $("v66_scenario").onchange=e=>scenario=e.target.value;
    $("v66_toggle_ue").onclick=()=>showUE=!showUE;
    $("v66_toggle_heat").onclick=()=>showHeat=!showHeat;
    $("v66_reset").onclick=()=>{power=1;noise=.12;speed=1.2;$("v66_power").value=1;$("v66_noise").value=.12;$("v66_speed").value=1.2;};
  }
  function drawUE(ctx,w,h,t){
    if(!showUE)return;
    ue.forEach((u,i)=>{
      const x=.5+Math.cos(t*0.00018*speed+u.a)*u.r+Math.sin(t*0.00011+u.o)*.04;
      const y=.5+Math.sin(t*0.00016*speed+u.a*1.7)*u.r*.62+Math.cos(t*0.00013+u.o)*.03;
      let best=0,bd=9;
      sites.forEach((s,idx)=>{const dx=x-(s.x*.5+.5),dy=y-(s.y*.5+.5);const d=dx*dx+dy*dy;if(d<bd){bd=d;best=idx;}});
      const c=["#42f56f","#8ff0ff","#fbbf24"][best];
      ctx.beginPath();ctx.arc(x*w,y*h,4,0,6.28);ctx.fillStyle=c;ctx.shadowColor=c;ctx.shadowBlur=16;ctx.fill();ctx.shadowBlur=0;
      const sx=(sites[best].x*.5+.5)*w, sy=(sites[best].y*.5+.5)*h;
      ctx.beginPath();ctx.moveTo(sx,sy);ctx.lineTo(x*w,y*h);ctx.strokeStyle=c+"99";ctx.lineWidth=1;ctx.stroke();
    });
  }
  function loop(now){
    const canvas=document.getElementById("v66_canvas");const dpr=Math.min(devicePixelRatio||1,2);
    const rw=canvas.clientWidth*dpr,rh=canvas.clientHeight*dpr;if(canvas.width!==rw||canvas.height!==rh){canvas.width=rw;canvas.height=rh;gl.viewport(0,0,rw,rh);}
    gl.useProgram(program);gl.uniform1f(loc.t,(now-start)/1000);gl.uniform1f(loc.power,power);gl.uniform1f(loc.noise,noise);gl.uniform1f(loc.heat,showHeat?1:0.18);gl.uniform1f(loc.scen,scenario==="mmwave"?2:scenario==="suburban"?1:0);gl.drawArrays(gl.TRIANGLE_STRIP,0,4);
    const ctx=canvas.getContext("2d"); if(ctx){drawUE(ctx,canvas.width,canvas.height,now);}
    frames++; if(now-last>1000){document.getElementById("v66_fps").textContent=String(frames);frames=0;last=now;updateKpis();}
    requestAnimationFrame(loop);
  }
  function updateKpis(){
    const rsrp=Math.round(-92+power*9-noise*18);
    const sinr=Math.round(24-noise*28+power*3);
    document.getElementById("v66_rsrp").textContent=rsrp+" dBm";
    document.getElementById("v66_sinr").textContent=sinr+" dB";
    document.getElementById("v66_cov").textContent=Math.max(55,Math.min(99,Math.round(88+power*8-noise*26)))+"%";
    document.getElementById("v66_ho").textContent=sinr>12?"READY":sinr>6?"WATCH":"DEGRADED";
  }
  document.addEventListener("DOMContentLoaded",init);
})();
