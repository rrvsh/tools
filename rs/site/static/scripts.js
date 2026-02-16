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
