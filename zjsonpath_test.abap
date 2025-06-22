*&---------------------------------------------------------------------*
*& Report zjsonpath_test
*&---------------------------------------------------------------------*
*& Test program for ABAP JSON Path class zcl_jsonpath
*&---------------------------------------------------------------------*
REPORT zjsonpath_test.

PARAMETERS: p_path TYPE string LOWER CASE DEFAULT '$.store.book[*].author',
            p_file AS CHECKBOX.

SELECTION-SCREEN SKIP.
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-t01.
  SELECTION-SCREEN COMMENT /1(50) TEXT-ex1.
  SELECTION-SCREEN COMMENT /1(50) TEXT-ex2.
  SELECTION-SCREEN COMMENT /1(50) TEXT-ex3.
  SELECTION-SCREEN COMMENT /1(50) TEXT-ex4.
  SELECTION-SCREEN COMMENT /1(50) TEXT-ex5.
  SELECTION-SCREEN COMMENT /1(50) TEXT-ex6.
  SELECTION-SCREEN COMMENT /1(50) TEXT-ex7.
SELECTION-SCREEN END OF BLOCK b1.

CONSTANTS:
  lc_file_filter TYPE string VALUE 'JSON Files (*.json)|*.json|All Files (*.*)|*.*'.

DATA:
  lt_file   TYPE STANDARD TABLE OF char1024,
  lv_json   TYPE string,
  lv_file   TYPE string,
  lt_files  TYPE filetable,
  lv_rc     TYPE i,
  lv_action TYPE i.

IF p_file EQ abap_true.

  cl_gui_frontend_services=>file_open_dialog(
    EXPORTING
      window_title            = 'Select JSON File'
      default_extension       = 'json'
      file_filter             = lc_file_filter
      initial_directory       = '/Users/ew_eki/Developer/abap/jsonPathwithABAP'
    CHANGING
      file_table              = lt_files
      rc                      = lv_rc
      user_action             = lv_action
    EXCEPTIONS
      file_open_dialog_failed = 1
      cntl_error              = 2
      error_no_gui            = 3
      not_supported_by_gui    = 4
      OTHERS                  = 5
  ).
  IF sy-subrc NE 0.
    MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
      WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
  ENDIF.

  IF lv_action EQ cl_gui_frontend_services=>action_cancel.
    MESSAGE s050(/ltb/tr_ui).
    RETURN.
  ENDIF.

  lv_file = VALUE #( lt_files[ 1 ]-filename OPTIONAL ).

  cl_gui_frontend_services=>gui_upload(
    EXPORTING
      filename                = lv_file
    CHANGING
      data_tab                = lt_file
    EXCEPTIONS
      file_open_error         = 1
      file_read_error         = 2
      no_batch                = 3
      gui_refuse_filetransfer = 4
      invalid_type            = 5
      no_authority            = 6
      unknown_error           = 7
      bad_data_format         = 8
      header_not_allowed      = 9
      separator_not_allowed   = 10
      header_too_long         = 11
      unknown_dp_error        = 12
      access_denied           = 13
      dp_out_of_memory        = 14
      disk_full               = 15
      dp_timeout              = 16
      not_supported_by_gui    = 17
      error_no_gui            = 18
      OTHERS                  = 19
  ).

  IF sy-subrc NE 0.
    MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
      WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
  ENDIF.

  " Convert internal table to json string
  lv_json = REDUCE string( INIT s = VALUE string(  ) FOR <line> IN lt_file NEXT s = s && <line> ).

ELSE.
  lv_json =
    `{ "store": { "book": [ { "category": "reference", "author": "Nigel Rees",` &&
    ` "title": "Sayings of the Century", "price": 8.95 },` &&
    `{ "category": "fiction", "author": "Evelyn Waugh", "title": "Sword of Honour", "price": 12.99 },` &&
    `{ "category": "fiction", "author": "Herman Melville", "title": "Moby Dick",` &&
    ` "isbn": "0-553-21311-3", "price": 8.99 },` &&
    `{ "category": "fiction", "author": "J. R. R. Tolkien", "title": "The Lord of the Rings",` &&
    ` "isbn": "0-395-19395-8", "price": 22.99 } ],` &&
    `"bicycle": { "color": "red", "price": 19.95 } } }`.
ENDIF.

CHECK lv_json IS NOT INITIAL.

DATA(jsonpath) = NEW zcl_jsonpath( ).
TRY.
    DATA(lt_result) = jsonpath->evaluate( iv_json = lv_json iv_jsonpath = p_path ).

    cl_demo_output=>begin_section( |JSON Path query results for: { p_path }| ).
    cl_demo_output=>write_data( lt_result ).
    cl_demo_output=>end_section( ).

    cl_demo_output=>begin_section( 'JSON file contents:' ).
    cl_demo_output=>display_json( lv_json ).
    cl_demo_output=>end_section( ).

    cl_demo_output=>display( ).

  CATCH zcx_jsonpath_error INTO DATA(error).
    cl_demo_output=>display( |ERROR: { error->if_message~get_text( ) }| ).
ENDTRY.

**********************************************************************