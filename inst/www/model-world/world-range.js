(function () {
  if (window.supposeWorldRangeRegistered) return;
  window.supposeWorldRangeRegistered = true;
  const binding = new Shiny.InputBinding();
  const values = (el) =>
    el.dataset.values ? JSON.parse(el.dataset.values) : null;
  const read = (el) => {
    const v = values(el);
    return v ? v[Number(el.value) - 1] : Number(el.value);
  };
  const show = (el) => {
    const value = read(el);
    document.getElementById(el.id + "-value").textContent = String(value);
    el.setAttribute("aria-valuetext", String(value));
  };
  const set = (el, value) => {
    const v = values(el);
    el.value = v
      ? v.reduce(
          (best, x, i) =>
            Math.abs(x - value) < Math.abs(v[best] - value) ? i : best,
          0,
        ) + 1
      : value;
    show(el);
  };
  Object.assign(binding, {
    find: (scope) => $(scope).find("input.suppose-world-range"),
    getValue: read,
    setValue: set,
    initialize: show,
    subscribe: (el, callback) =>
      $(el).on("input.supposeWorldRange change.supposeWorldRange", () => {
        show(el);
        callback(false);
      }),
    unsubscribe: (el) => $(el).off(".supposeWorldRange"),
    getRatePolicy: () => ({ policy: "debounce", delay: 100 }),
    receiveMessage: (el, data) => {
      const previous = read(el);
      if (data.values !== undefined) {
        el.dataset.values = JSON.stringify(data.values);
        el.min = 1;
        el.max = data.values.length;
        el.step = 1;
      } else if (!values(el)) {
        for (const key of ["min", "max", "step"])
          if (data[key] !== undefined) el[key] = data[key];
      }
      if (data.label !== undefined)
        document.getElementById(el.id + "-label").textContent = data.label;
      for (const key of ["min", "max"])
        if (data[key] !== undefined)
          document.getElementById(el.id + "-" + key).textContent = String(
            data[key],
          );
      set(el, data.value === undefined ? previous : data.value);
      $(el).trigger("change");
    },
  });
  Shiny.inputBindings.register(binding, "suppose.worldRange");
})();
