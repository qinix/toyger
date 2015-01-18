root = exports ? this

toyger = root.toyger =
  content_id: "#content"
  sidebar_id: "#sidebar"

  edit_id: "#edit"
  back_to_top_id: "#back_to_top"

  loading_id: "#loading"
  error_id: "#error"

  search_name: "#search"
  search_results_class: ".search_results"
  fragments_class: ".fragments"
  fragment_class: ".fragment"

  # display elements
  sidebar: true
  edit_button: true
  back_to_top_button: true
  searchbar: true

  # github specifics
  github_username: null
  github_repo: null

toyger.run = (options) ->
  $.extend toyger, options

  init_sidebar_section() if toyger.sidebar
  init_back_to_top_button() if toyger.back_to_top_button
  init_edit_button() if toyger.edit_button

  router()
  $(window).on('hashchange', router)

init_sidebar_section = ->
  $.get toyger.sidebar_file, (data) ->
    $(toyger.sidebar_id).html(kramed(data))

    init_searchbar() if toyger.searchbar;
  , "text"
  .fail ->
    alert 'Oops! can\'t find the sidebar file to display!'

init_back_to_top_button = ->
  $(toyger.back_to_top_id).show()
  $(toyger.back_to_top_id).on "click", ->
    $("body,html").animate
      scrollTop: 0
    , 200

init_edit_button = ->
  if not toyger.base_url?
    alert "Error! you didn't set 'base_url' when calling toyger.run()!"
  else
    $(toyger.edit_id).show()
    $(toyger.edit_id).on "click", ->
      hash = location.hash.replace("#", "/")
      hash = "/" + toyger.index.replace(".md", "") if hash == ""

      window.open "#{toyger.base_url}#{hash}.md"

init_searchbar = ->
  sidebar = $(toyger.sidebar_id).html()
  match = "toyger:searchbar"

  # html input searchbar
  search = "<input name='#{toyger.search_name}' type='search' results='10'>"

  # replace match code with a real html input search bar
  sidebar = sidebar.replace match, search
  $(toyger.sidebar_id).html sidebar

  # add search listener
  $("input[name=#{toyger.search_name}]").keydown searchbar_listener

build_text_matches_html = (fragments) ->
  html = ''
  class_name = toyger.fragments_class.replace '.', ''

  html += "<ul class='#{class_name}'>"
  for f in fragments
    fragment = f.fragment.replace("/[\uE000-\uF8FF]/g", "")
    html += "<li class='#{toyger.fragment_class.replace(".", "")}'>'"
    html += "<pre><code> "
    fragment = $("#hide").text(fragment).html()
    html += fragment
    html += " </code></pre></li>"
  html += "</ul>"
  html

build_result_matches_html = (matches) ->
  html = ''
  class_name = toyger.search_results_class.replace(".", "")

  html += "<ul class='#{class_name}'>'"
  for m in matches
    url = m.path

    if url != toyger.sidebar_file
      hash = "\##{url.replace('.md', '')}"
      path = window.location.origin + '/' + hash

      html += "<li class='link'>"
      html += url
      match = build_text_matches_html(m.text_matches)
      html += match
  html += "</ul>"
  html

display_search_results = (data) ->
  results_html = "<h1>Search Results</h1>"

  console.log data

  if data.items.length > 0
    $(toyger.error_id).hide()
    results_html += build_result_matches_html data.items
  else
    show_error "Oops! No matches found"

  $(toyger.content_id).html result_html
  $(toyger.search_results_class + ' .link').click ->
    destination = "\##{$(this).html().replace('.md', '')}"
    location.hash = destination

github_search = (query) ->
  if toyger.github_username and toyger.github_repo
    github_api = "https://api.github.com/"
    search = "search/code?q="
    github_repo = toyger.github_username + '/' + toyger.github_repo
    search_details = '+in:file+language:markdown+repo:'
    url = github_api + search + query + search_details + github_repo
    accept_header = 'application/vnd.github.v3.text-match+json'

    $.ajax url,
      headers:
        Accept: accept_header
    .done (data) ->
      display_search_results data

  switch
    when !toyger.github_username? and !toyger.github_repo? then alert("You have not set github_username and github_repo!")
    when !toyger.github_username? then alert("You have not set github_username!")
    when !toyger.github_repo? then alert("You have not set github_repo")

searchbar_listener = (event) ->
  if event.which == 13
    q = $("input[name=#{toyger.search_name}]").val()
    if q != ''
      location.hash = "\##search=#{q}"
    else
      alert('Error! Empty search query!')

replace_symbols = (text) ->
  # replace symbols with underscore
  text.replace /[$\/\\#,+=()$~%.'":*?<>{}\ \]\[]/g, '_'

li_create_linkage = (li_tag, header_level) ->
  # add custom id and class attributes
  html_safe_tag = replace_symbols(li_tag.text())
  li_tag.attr("id", html_safe_tag)
  li_tag.attr("class", "link")

  # add click listener - on click scroll to relevant header seation
  $(toyger.content_id + " li\#" + li_tag.attr("id")).click ->
    # scroll to relevant section
    header = $(toyger.content_id + " h" + header_level + '.' + li_tag.attr('id'))
    $('html, body').animate
      scrollTop: header.offset().top
    , 200

    # highlight the relevant section
    original_color = header.css("color")
    header.animate
      color: "\#ED1C24"
    , 500, ->
      # revert back to orig color
      $(this).animate
        color: original_color
      , 2500

create_page_anchors = ->
  # create page anchors by matching li's to headers
  # if there is a match, create click listeners
  # and scroll to relevant sections

  # go through header level 2 and 3
  for i in [2..4]
    # parse all headers
    headers = []
    $(toyger.content_id + ' h' + i).map ->
      headers.push($(this).text())
      $(this).addClass(replace_symbols($(this).text()))

    # parse and set links between li and h2
    $(toyger.content_id + ' ul li').map ->
      for j in [0...headers.length]
        li_create_linkage($(this), i) if headers[j] == $(this).text()

normalize_paths = ->
  # images
  $(toyger.content_id + ' img').map ->
    src = $(this).attr('src').replace('./', '')
    if $(this).attr('src').slice(0, 5) != 'http'
      url = location.hash.replace('#', '')

      # split and extract base dir
      console.log url
      url = url.split '/'
      base_dir = url.slice(0, url.length - 1).join('/')

      # normalize the path (i.e. make it absolute)
      if base_dir
        $(this).attr('src', base_dir + '/' + src)
      else
        $(this).attr('src', src)

show_error = (err_msg) ->
  $(toyger.error_id).html(err_msg)
  $(toyger.error_id).show()

show_loading = ->
  $(toyger.loading_id).show()
  $(toyger.content_id).html('')

  # infinite loop until clearInterval() is called on loading
  loading = setInterval ->
    $(toyger.loading_id).fadeIn(1000).fadeOut(1000)
  , 2000

escape_github_badges = (data) ->
  $('img').map ->
    ignore_list = [
      'travis-ci.org'
      'coveralls.io'
    ]
    src = $(this).attr('src')

    base_url = src.split('/')
    protocal = base_url[0]
    host = base_url[2]

    $(this).attr('class', 'github_badges') if $.inArray(host, ignore_list) >= 0

  data

page_getter = ->
  # When we fetch a new page we want to scroll back to the
  # top of the window, otherwise we may show the user the
  # middle of an existing document
  window.scrollTo(0, 0)

  path = location.hash.replace('#', './')

  # default page if hash is empty
  current_page = location.pathname.split('/').pop()
  if current_page == 'index.html'
    path = location.pathname.replace('index.html', toyger.index)
    normalize_paths()
  else if path == ''
    path = window.location + toyger.index
    normalize_paths()
  else
    path = path + '.md'

  loading = show_loading()
  $.get path, (data) ->
    $(toyger.error_id).hide()
    data = kramed data
    $(toyger.content_id).html data
    escape_github_badges data

    normalize_paths()
    create_page_anchors()

    $('pre code').each (i, block) ->
      hljs.highlightBlock(block) if hljs?
  .fail ->
    show_error('Oops! ... File not found!')
  .always ->
    clearInterval loading
    $(toyger.loading_id).hide()

router = ->
  hash = location.hash
  if hash.slice(1, 7) != 'search'
    page_getter()
  else
    github_search hash.replace '#search=', '' if toyger.searchbar
