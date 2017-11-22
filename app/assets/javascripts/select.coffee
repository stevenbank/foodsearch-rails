$(document).on 'click', '#display-link', (event) ->
  event.preventDefault()
  location = document.getElementById('restaurants')
  style = location.style.flexWrap
  if style == 'nowrap'
    change_display_style(location, 'wrap', 'center', '', 'visible')
  else
    change_display_style(location, 'nowrap', 'flex-start', 'auto', 'hidden')
  return

change_display_style = (location, wrap, justify ,overflow, visibility) ->
  up = document.getElementById('up-link')
  location.style.flexWrap = wrap
  location.style.justifyContent = justify
  location.style.overflowX = overflow
  up.style.visibility = visibility
  window.scroll_to_card(wrap)
