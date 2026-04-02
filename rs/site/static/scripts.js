const backToTopButton = document.querySelector("#back-to-top");
backToTopButton.addEventListener("click", () => {
  window.scrollTo(0, 0);
});

const backToHomeButton = document.querySelector("#back-to-home");
if (window.location.pathname ===  "/") {
  backToHomeButton.style.display = "none";
} else {
  backToHomeButton.style.display = "inline-block";
}
backToHomeButton.addEventListener("click", () => {
  window.location.href = "/";
});

const pageBottomSentinel = document.querySelector("#page-bottom-sentinel");
if (pageBottomSentinel) {
  const observer = new IntersectionObserver(([entry]) => {
    document.body.classList.toggle("is-at-page-bottom", entry.isIntersecting);
  });
  observer.observe(pageBottomSentinel);
}
