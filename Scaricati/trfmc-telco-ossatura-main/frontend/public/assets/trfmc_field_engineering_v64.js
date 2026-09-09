(function(){
  function ready(fn){
    document.readyState==="loading"
      ? document.addEventListener("DOMContentLoaded",fn)
      : fn();
  }

  ready(()=>{
    document.title="TRFMC v0.64A · Field Engineering Mode";
  });
})();
