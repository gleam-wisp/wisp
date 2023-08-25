function update() {
  document.body.innerText = new Date().toLocaleTimeString();
}

setInterval(update, 1000);
update();
