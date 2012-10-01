$ ->
  $('form.startup textarea, form.checkin textarea').autosize()
  $('a[rel=tooltip]').tooltip()

  if $('form.checkin').length > 0
    setTimeout( ->
      enableCheckinFormIfComplete(true)
    , 1000)

  $('.video_form .youtube_url').change( ->
    console.log 'change'
    video_id = $(this).data('video-id')
    url = $(this).val()
    if isValidYoutubeUrl(url)
      $("##{video_id} .completed").show()
      $("##{video_id} .fields").hide()
    else
      $("##{video_id} .completed").hide()
      $("##{video_id} .fields").show()
  )

  # if they choose to record again
  # $('.video_form .record_again').click ->
  #   video_id = $(this).data('video_id')
  #   $("##{video_id} .completed").show()
  #   $("##{video_id} .fields").hide()

  isValidYoutubeUrl = (string) ->
    # http://www.youtube.com/?watch?v=id
    return true if string.match(/^http\:\/\/.*youtube\.com\/watch\?v\=.+$/)
    # http://www.youtu.be/?watch=id
    return true if string.match(/^http\:\/\/.*youtu\.be\/watch\?v\=.+$/)
    # http://www.youtube.com/embed/id
    return true if string.match(/^http\:\/\/.*youtube\.com\/embed\/.+$/)
    false

  enableCheckinFormIfComplete = (add_timer = false) ->
    type = $('#checkin_type').val()
    is_complete = false
    if type == 'before'
      is_complete = true if $('.video_form .completed:visible').length == 1 && $('.checkin_start_focus').val().length > 0
    else if type == 'after'
      is_complete = true if $('.video_form .completed:visible').length == 1 && $('.checkin_accomplished').is(':checked') && $('.checkin_end_comments').val().length > 0
    if is_complete
      console.log 'complete'
      $('form.checkin :submit').removeClass('disabled').removeAttr('disabled')
    else
      console.log 'not complete'
      $('form.checkin :submit').addClass('disabled').attr('disabled', true)
    if add_timer
      setTimeout( ->
        enableCheckinFormIfComplete(true)
      , 1000)

  # Logic for showing/hiding video embedding
  $('.video_embed_buttons .button').click (e) ->
    e.preventDefault()
    video_id = $(this).data('video-id')
    type = $(this).data('embed-class')
    $("##{video_id} .video_embed_buttons, .video_embed").hide()
    $("##{video_id} .video_embed_cancel").show()
    $("##{video_id} .#{type}").show()
    if type == 'screenr_embed'
      startRecording()

  $('.video_embed_cancel a').click (e) ->
    e.preventDefault()
    video_id = $(this).data('video-id')
    $("##{video_id} .video_embed_cancel, .video_embed").hide()
    $("##{video_id} .video_embed_buttons").show()
    

  