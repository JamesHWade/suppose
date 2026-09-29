$(document).on("shiny:inputchanged", function (e) {
  if (["inquiry_message_edit", "inquiry_message_navigate"].includes(e.name))
    e.preventDefault();
});
$(document).on("shiny:connected", function () {
  Shiny.addCustomMessageHandler("suppose-open-section", function (id) {
    if (
      ![
        "import-panel",
        "prospective-panel",
        "measurements-panel",
        "sensitivity-panel",
        "extension-panel",
        "regression-panel",
        "design-panel",
        "regression_test-panel",
        "regression_sensitivity-panel",
      ].includes(id)
    )
      return;
    const panel = document.getElementById(id);
    if (panel) {
      panel.open = true;
      setTimeout(function () {
        panel.scrollIntoView({ block: "start" });
      }, 250);
    }
  });
});
