(function(){
  const sites=[
    {x:-0.58,y:-0.20,p:1.05},
    {x:0.48,y:-0.05,p:0.92},
    {x:0.02,y:0.48,p:0.78}
  ];

  const buildings=[
    [-0.22,-0.05,0.10,0.42],
    [0.20,0.18,0.13,0.36],
    [0.03,-0.34,0.15,0.30],
    [-0.48,0.34,0.11,0.26],
    [0.46,-0.28,0.09,0.40]
  ];

  let gl,program,loc={},buf,start=performance.now(),frames=0,last=performance.now();
  let power=1,noise=.12,speed=1.2,clutter=.65,showUE=true,showHeat=true;
  const ue=Array.from({length:36},(_,i)=>({a:Math.random()*6.28,r:.16+Math.random()*.72,o:i*.31}));

  function $(id){return document.getElementById(id);}
  function shader(type,src){
    const s=gl.createShader(type);
    gl.shaderSource(s,src);
    gl.compileShader(s);
    if(!gl.getShaderParameter(s,gl.COMPILE_STATUS)) throw gl.getShaderInfoLog(s);
    return s;
  }

  function initUI(){
    const side=document.querySelector(".v66-side-panel");
    if(!side || document.querySelector(".v67-clutter-panel")) return;

    const panel=document.createElement("div");
    panel.className="v67-clutter-panel";
    panel.innerHTML=`
      <h3>Urban Shadowing / Clutter</h3>
      <p>Gli edifici applicano penalità NLOS alla copertura e generano zone d'ombra RF.</p>
      <label>Clutter Loss</label>
      <input id="v67_clutter" type="range" min="0" max="1" step="0.01" value="0.65"/>
    `;
    side.appendChild(panel);

    $("v67_clutter").oninput=e=>clutter=parseFloat(e.target.value);

    const wrap=document.querySelector(".v66-canvas-wrap");
    if(wrap && !document.querySelector(".v67-obstacle-legend")){
      const l=document.createElement("div");
      l.className="v67-obstacle-legend";
      l.textContent="AMBER BLOCKS = urban clutter / NLOS attenuation";
      wrap.appendChild(l);
    }
  }

  function initGL(){
    const canvas=$("v66_canvas");
    gl=canvas.getContext("webgl",{antialias:true,preserveDrawingBuffer:false});
    if(!gl){$("v66_state").textContent="WEBGL UNAVAILABLE";return;}

    const vs=`attribute vec2 p; varying vec2 v; void main(){v=p; gl_Position=vec4(p,0.0,1.0);}`;

    const fs=`precision highp float;
      varying vec2 v;
      uniform float t;
      uniform float power;
      uniform float noise;
      uniform float heat;
      uniform float clutter;

      float box(vec2 p, vec2 c, vec2 s){
        vec2 d=abs(p-c)-s;
        return length(max(d,0.0))+min(max(d.x,d.y),0.0);
      }

      float losPenalty(vec2 p, vec2 site, vec2 c, vec2 s, float strength){
        vec2 dir=p-site;
        float len=length(dir);
        vec2 n=dir/max(len,0.001);
        float best=1.0;
        for(int i=0;i<32;i++){
          float u=float(i)/31.0;
          vec2 q=site+n*len*u;
          float b=box(q,c,s);
          float hit=1.0-smoothstep(0.0,0.035,b);
          best=min(best,1.0-hit*strength);
        }
        return best;
      }

      float buildingMask(vec2 p){
        float m=0.0;
        m=max(m,1.0-smoothstep(0.0,0.015,box(p,vec2(-.22,-.05),vec2(.10,.42))));
        m=max(m,1.0-smoothstep(0.0,0.015,box(p,vec2(.20,.18),vec2(.13,.36))));
        m=max(m,1.0-smoothstep(0.0,0.015,box(p,vec2(.03,-.34),vec2(.15,.30))));
        m=max(m,1.0-smoothstep(0.0,0.015,box(p,vec2(-.48,.34),vec2(.11,.26))));
        m=max(m,1.0-smoothstep(0.0,0.015,box(p,vec2(.46,-.28),vec2(.09,.40))));
        return m;
      }

      float shadow(vec2 p, vec2 s){
        float k=1.0;
        k*=losPenalty(p,s,vec2(-.22,-.05),vec2(.10,.42),clutter);
        k*=losPenalty(p,s,vec2(.20,.18),vec2(.13,.36),clutter*.95);
        k*=losPenalty(p,s,vec2(.03,-.34),vec2(.15,.30),clutter*.85);
        k*=losPenalty(p,s,vec2(-.48,.34),vec2(.11,.26),clutter*.80);
        k*=losPenalty(p,s,vec2(.46,-.28),vec2(.09,.40),clutter*.90);
        return k;
      }

      float site(vec2 p, vec2 s, float pw, float az){
        vec2 d=p-s;
        float r=length(d);
        float a=atan(d.y,d.x);
        float beam=pow(max(0.0,cos(a-az)),6.0);
        float fspl=pw/(0.050+r*r*2.35);
        return fspl*(.30+.92*beam)*shadow(p,s);
      }

      vec3 ramp(float x){
        x=clamp(x,0.0,1.0);
        vec3 a=vec3(.015,.035,.13), b=vec3(.0,.42,1.0), c=vec3(.12,1.0,.38), d=vec3(1.0,.70,.10), e=vec3(1.0,.06,.28);
        if(x<.25)return mix(a,b,x/.25);
        if(x<.52)return mix(b,c,(x-.25)/.27);
        if(x<.78)return mix(c,d,(x-.52)/.26);
        return mix(d,e,(x-.78)/.22);
      }

      void main(){
        vec2 p=v;
        float f=0.0;
        f+=site(p,vec2(-.58,-.20),1.05*power,.10);
        f+=site(p,vec2(.48,-.05),.92*power,3.05);
        f+=site(p,vec2(.02,.48),.78*power,-1.55);

        float rand=fract(sin(dot(p+t*.01,vec2(12.9898,78.233)))*43758.5453);
        f-=noise*(.24+.76*rand);
        f*=heat;

        vec3 col=ramp(f*.78);
        float b=buildingMask(p);
        col=mix(col,vec3(1.0,.55,.06),b*.74);

        float grid=(step(.988,cos(p.x*72.0))*0.025)+(step(.988,cos(p.y*72.0))*0.025);
        col+=grid*vec3(.22,.85,1.0);

        float vign=1.0-smoothstep(.58,1.28,length(p));
        col*=.42+.82*vign;
        gl_FragColor=vec4(col,1.0);
      }`;

    program=gl.createProgram();
    gl.attachShader(program,shader(gl.VERTEX_SHADER,vs));
    gl.attachShader(program,shader(gl.FRAGMENT_SHADER,fs));
    gl.linkProgram(program);
    if(!gl.getProgramParameter(program,gl.LINK_STATUS)) throw gl.getProgramInfoLog(program);

    gl.useProgram(program);
    buf=gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER,buf);
    gl.bufferData(gl.ARRAY_BUFFER,new Float32Array([-1,-1,1,-1,-1,1,1,1]),gl.STATIC_DRAW);

    const p=gl.getAttribLocation(program,"p");
    gl.enableVertexAttribArray(p);
    gl.vertexAttribPointer(p,2,gl.FLOAT,false,0,0);

    ["t","power","noise","heat","clutter"].forEach(k=>loc[k]=gl.getUniformLocation(program,k));

    $("v66_state").textContent="URBAN SHADOWING READY";
    $("v66_renderer").textContent=gl.getParameter(gl.RENDERER).slice(0,24);

    bind();
    requestAnimationFrame(loop);
  }

  function bind(){
    $("v66_power").oninput=e=>power=parseFloat(e.target.value);
    $("v66_noise").oninput=e=>noise=parseFloat(e.target.value);
    $("v66_speed").oninput=e=>speed=parseFloat(e.target.value);
    $("v66_toggle_ue").onclick=()=>showUE=!showUE;
    $("v66_toggle_heat").onclick=()=>showHeat=!showHeat;
    $("v66_reset").onclick=()=>{
      power=1;noise=.12;speed=1.2;clutter=.65;
      $("v66_power").value=1;$("v66_noise").value=.12;$("v66_speed").value=1.2;
      if($("v67_clutter")) $("v67_clutter").value=.65;
    };
  }

  function drawUE(ctx,w,h,t){
    if(!showUE)return;
    ue.forEach((u)=>{
      const x=.5+Math.cos(t*0.00018*speed+u.a)*u.r+Math.sin(t*0.00011+u.o)*.04;
      const y=.5+Math.sin(t*0.00016*speed+u.a*1.7)*u.r*.62+Math.cos(t*0.00013+u.o)*.03;

      let best=0,bd=99;
      sites.forEach((s,idx)=>{
        const dx=x-(s.x*.5+.5),dy=y-(s.y*.5+.5);
        const d=dx*dx+dy*dy;
        if(d<bd){bd=d;best=idx;}
      });

      const c=["#42f56f","#8ff0ff","#fbbf24"][best];
      const sx=(sites[best].x*.5+.5)*w, sy=(sites[best].y*.5+.5)*h;

      ctx.beginPath();
      ctx.moveTo(sx,sy);
      ctx.lineTo(x*w,y*h);
      ctx.strokeStyle=c+"88";
      ctx.lineWidth=1;
      ctx.stroke();

      ctx.beginPath();
      ctx.arc(x*w,y*h,4,0,6.28);
      ctx.fillStyle=c;
      ctx.shadowColor=c;
      ctx.shadowBlur=16;
      ctx.fill();
      ctx.shadowBlur=0;
    });
  }

  function loop(now){
    const canvas=$("v66_canvas");
    const dpr=Math.min(devicePixelRatio||1,2);
    const rw=canvas.clientWidth*dpr, rh=canvas.clientHeight*dpr;
    if(canvas.width!==rw || canvas.height!==rh){
      canvas.width=rw; canvas.height=rh; gl.viewport(0,0,rw,rh);
    }

    gl.useProgram(program);
    gl.uniform1f(loc.t,(now-start)/1000);
    gl.uniform1f(loc.power,power);
    gl.uniform1f(loc.noise,noise);
    gl.uniform1f(loc.heat,showHeat?1:.18);
    gl.uniform1f(loc.clutter,clutter);
    gl.drawArrays(gl.TRIANGLE_STRIP,0,4);

    const ctx=canvas.getContext("2d");
    if(ctx) drawUE(ctx,canvas.width,canvas.height,now);

    frames++;
    if(now-last>1000){
      $("v66_fps").textContent=String(frames);
      frames=0; last=now;
      const rsrp=Math.round(-94+power*10-noise*18-clutter*7);
      const sinr=Math.round(23-noise*28+power*3-clutter*5);
      $("v66_rsrp").textContent=rsrp+" dBm";
      $("v66_sinr").textContent=sinr+" dB";
      $("v66_cov").textContent=Math.max(45,Math.min(98,Math.round(88+power*8-noise*24-clutter*16)))+"%";
      $("v66_ho").textContent=sinr>12?"READY":sinr>6?"WATCH":"NLOS RISK";
    }

    requestAnimationFrame(loop);
  }

  document.addEventListener("DOMContentLoaded",()=>{
    initUI();
    initGL();
  });
})();
