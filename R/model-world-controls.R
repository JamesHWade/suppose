world_range_input <- function(
  id,
  label,
  min,
  max,
  value,
  step = 1,
  values = NULL
) {
  position <- if (is.null(values)) value else which.min(abs(values - value))
  shown <- if (is.null(values)) position else values[position]
  shiny::tags$div(
    class = 'shiny-input-container world-range-container',
    shiny::tags$label(id = paste0(id, '-label'), `for` = id, label),
    shiny::tags$output(id = paste0(id, '-value'), `for` = id, shown),
    shiny::tags$input(
      id = id,
      type = 'range',
      class = 'suppose-world-range',
      min = if (is.null(values)) min else 1,
      max = if (is.null(values)) max else length(values),
      step = if (is.null(values)) step else 1,
      value = position,
      `aria-valuetext` = as.character(shown),
      `data-values` = if (is.null(values)) {
        NULL
      } else {
        as.character(jsonlite::toJSON(values, auto_unbox = FALSE))
      }
    ),
    shiny::tags$div(
      class = 'world-range-ends',
      shiny::tags$span(id = paste0(id, '-min'), min),
      shiny::tags$span(id = paste0(id, '-max'), max)
    )
  )
}

world_update_slider <- function(
  session,
  id,
  label = NULL,
  min = NULL,
  max = NULL,
  value = NULL,
  step = NULL,
  values = NULL
) {
  data <- list(
    label = label,
    min = min,
    max = max,
    value = value,
    step = step,
    values = values
  )
  data <- data[!vapply(data, is.null, logical(1))]
  session$sendInputMessage(id, data)
}

world_range_binding <- function() {
  shiny::tags$script(shiny::HTML(
    "(function(){
    if(window.supposeWorldRangeRegistered) return;
    window.supposeWorldRangeRegistered=true;
    const binding=new Shiny.InputBinding();
    const values=el=>el.dataset.values?JSON.parse(el.dataset.values):null;
    const read=el=>{const v=values(el);return v?v[Number(el.value)-1]:Number(el.value);};
    const show=el=>{const value=read(el);document.getElementById(el.id+'-value').textContent=String(value);el.setAttribute('aria-valuetext',String(value));};
    const set=(el,value)=>{const v=values(el);el.value=v?v.reduce((best,x,i)=>Math.abs(x-value)<Math.abs(v[best]-value)?i:best,0)+1:value;show(el);};
    Object.assign(binding,{
      find:scope=>$(scope).find('input.suppose-world-range'),
      getValue:read,
      setValue:set,
      initialize:show,
      subscribe:(el,callback)=>$(el).on('input.supposeWorldRange change.supposeWorldRange',()=>{show(el);callback(false);}),
      unsubscribe:el=>$(el).off('.supposeWorldRange'),
      getRatePolicy:()=>({policy:'debounce',delay:100}),
      receiveMessage:(el,data)=>{
        const previous=read(el);
        if(data.values!==undefined){el.dataset.values=JSON.stringify(data.values);el.min=1;el.max=data.values.length;el.step=1;}
        else if(!values(el)){for(const key of ['min','max','step'])if(data[key]!==undefined)el[key]=data[key];}
        if(data.label!==undefined)document.getElementById(el.id+'-label').textContent=data.label;
        for(const key of ['min','max'])if(data[key]!==undefined)document.getElementById(el.id+'-'+key).textContent=String(data[key]);
        set(el,data.value===undefined?previous:data.value);
        $(el).trigger('change');
      }
    });
    Shiny.inputBindings.register(binding,'suppose.worldRange');
  })();"
  ))
}
