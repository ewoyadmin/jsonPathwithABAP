CLASS zcx_jsonpath_error DEFINITION
  PUBLIC
  INHERITING FROM cx_static_check
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_t100_message.
    METHODS constructor
      IMPORTING
        textid   LIKE if_t100_message=>t100key OPTIONAL
        previous LIKE previous OPTIONAL.
  PROTECTED SECTION.
  PRIVATE SECTION.

ENDCLASS.

CLASS zcx_jsonpath_error IMPLEMENTATION.

  METHOD constructor ##ADT_SUPPRESS_GENERATION.
    super->constructor( previous = previous ).
    me->if_t100_message~t100key = textid.
  ENDMETHOD.

ENDCLASS.