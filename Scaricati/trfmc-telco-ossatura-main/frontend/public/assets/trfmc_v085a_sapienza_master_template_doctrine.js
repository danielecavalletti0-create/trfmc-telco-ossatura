(function(){
  document.addEventListener("DOMContentLoaded",()=>{
    const rows=[...document.querySelectorAll("tbody tr")];
    rows.forEach((r,i)=>{
      r.style.opacity="0";
      r.style.transform="translateY(8px)";
      setTimeout(()=>{
        r.style.transition="opacity .35s ease, transform .35s ease";
        r.style.opacity="1";
        r.style.transform="translateY(0)";
      },120+i*60);
    });

    const cards=[...document.querySelectorAll(".doctrine-grid article")];
    cards.forEach(card=>{
      card.addEventListener("mouseenter",()=>card.style.borderColor="rgba(66,245,111,.42)");
      card.addEventListener("mouseleave",()=>card.style.borderColor="rgba(143,240,255,.30)");
    });
  });
})();
