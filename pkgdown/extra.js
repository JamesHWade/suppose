// Let the standard skip link move keyboard focus to the main content.
document.addEventListener('DOMContentLoaded', () => {
  const main = document.getElementById('main');
  if (main) main.setAttribute('tabindex', '-1');
});
