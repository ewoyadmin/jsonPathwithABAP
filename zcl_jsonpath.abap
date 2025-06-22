CLASS zcl_jsonpath DEFINITION PUBLIC FINAL CREATE PUBLIC .
  PUBLIC SECTION.
    TYPES:
      tt_nodes TYPE STANDARD TABLE OF REF TO data, " Table type for holding references to data nodes
      BEGIN OF ty_result,
        value TYPE string,                     " Value extracted by JSONPath
      END OF ty_result,
      ty_result_table TYPE STANDARD TABLE OF ty_result WITH EMPTY KEY, " Table type for returning JSONPath results
      string_table TYPE STANDARD TABLE OF string WITH EMPTY KEY.      " Table type for splitting JSONPath into segments

    METHODS evaluate
      IMPORTING
        iv_json     TYPE string    " Input JSON string
        iv_jsonpath TYPE string    " JSONPath expression
      RETURNING
        VALUE(rt_result) TYPE ty_result_table " Resulting values
      RAISING
        zcx_jsonpath_error. " Exception for JSONPath errors

  PROTECTED SECTION.
  PRIVATE SECTION.
    METHODS parse_path
      IMPORTING
        iv_jsonpath TYPE string        " JSONPath expression to parse
      RETURNING
        VALUE(rt_path) TYPE string_table " Parsed JSONPath segments
      RAISING
        zcx_jsonpath_error. " Exception for parsing errors

    METHODS navigate
      IMPORTING
        it_nodes TYPE tt_nodes       " Current set of nodes to navigate
        it_path  TYPE string_table   " Remaining JSONPath segments
      RETURNING
        VALUE(rt_result) TYPE ty_result_table. " Resulting values after navigation
ENDCLASS.


CLASS zcl_jsonpath IMPLEMENTATION.

  METHOD evaluate.
    DATA: lo_data TYPE REF TO data. " Reference to hold deserialized JSON data

    TRY.
" Deserialize the input JSON string into an ABAP data object
        /ui2/cl_json=>deserialize( EXPORTING json = iv_json CHANGING data = lo_data ).
    CATCH zcx_jsonpath_error.
" Re-raise any deserialization errors
        RAISE EXCEPTION TYPE zcx_jsonpath_error.
    ENDTRY.

" Parse the JSONPath expression into individual path segments
    DATA(lt_path) = parse_path( iv_jsonpath ).

    DATA lt_current_nodes TYPE STANDARD TABLE OF REF TO data.
" Start navigation from the root node (deserialized JSON data)
    APPEND lo_data TO lt_current_nodes.

" Navigate through the data structure using the parsed path
    rt_result = navigate( it_nodes = lt_current_nodes it_path = lt_path ).

  ENDMETHOD.


  METHOD navigate.
    DATA: lt_next_nodes TYPE STANDARD TABLE OF REF TO data. " Nodes found after current navigation step

" If the path is empty, we have reached the target nodes, so extract their values
    IF it_path IS INITIAL.
      LOOP AT it_nodes INTO DATA(lo_node).
" Assign the content of the data reference to a field symbol
        ASSIGN lo_node->* TO FIELD-SYMBOL(<fs_data>).
        IF <fs_data> IS ASSIGNED.
" Describe the type of the current data
          DATA(lo_type) = cl_abap_typedescr=>describe_by_data( <fs_data> ).
          CASE lo_type->kind.
            WHEN cl_abap_typedescr=>kind_ref.
" If it's a reference, dereference it to get the actual data
              ASSIGN <fs_data>->* TO FIELD-SYMBOL(<fs_ref_data>).
              IF <fs_ref_data> IS ASSIGNED.
                lo_type = cl_abap_typedescr=>describe_by_data( <fs_ref_data> ).
                ASSIGN <fs_ref_data> TO <fs_data>. " Update <fs_data> to point to the dereferenced data
              ENDIF.
          ENDCASE.

          CASE lo_type->kind.
            WHEN cl_abap_typedescr=>kind_elem.
" If it's an elementary type, add its value directly to the result
              APPEND VALUE #( value = <fs_data> ) TO rt_result.
            WHEN cl_abap_typedescr=>kind_struct OR cl_abap_typedescr=>kind_table.
" If it's a structure or table, serialize it back to JSON and add to result
              TRY.
                  DATA(lv_json) = /ui2/cl_json=>serialize( data = <fs_data> ).
                  APPEND VALUE #( value = lv_json ) TO rt_result.
                CATCH zcx_jsonpath_error.
" Ignore nodes that cannot be serialized (e.g., circular references, unsupported types)
              ENDTRY.
            WHEN OTHERS.
" Optionally handle other ABAP types if needed
          ENDCASE.
        ENDIF.
      ENDLOOP.
      RETURN. " Navigation complete for this path
    ENDIF.

" Get the current path element and the remaining path
    DATA(lv_path_element) = it_path[ 1 ].
    DATA(lt_remaining_path) = it_path.
    DELETE lt_remaining_path INDEX 1.

    LOOP AT it_nodes INTO lo_node.
" Assign the content of the data reference to a field symbol
      ASSIGN lo_node->* TO <fs_data>.
      IF <fs_data> IS NOT ASSIGNED.
        CONTINUE. " Skip if data is not assigned
      ENDIF.

" Describe the type of the current data node
      DATA(lo_typedescr) = cl_abap_typedescr=>describe_by_data( <fs_data> ).
      CASE lo_typedescr->kind.
        WHEN cl_abap_typedescr=>kind_ref.
" If it's a reference, dereference it
          ASSIGN <fs_data>->* TO FIELD-SYMBOL(<fs_ref_data>).
          IF <fs_ref_data> IS ASSIGNED.
            lo_typedescr = cl_abap_typedescr=>describe_by_data( <fs_ref_data> ).
            ASSIGN <fs_ref_data> TO <fs_data>. " Update <fs_data> to point to the dereferenced data
          ENDIF.
      ENDCASE.

" Handle the 'PIPE' operator for chaining multiple JSONPath expressions
      IF lv_path_element = 'PIPE'.
" Continue navigation with the remaining path, using the current nodes as input
" This allows for operations like "$.store.book | $.store.bicycle"
        rt_result = navigate( it_nodes = it_nodes it_path = lt_remaining_path ).
        RETURN.
      ENDIF.

" Process the current node based on its type and the path element
      CASE lo_typedescr->kind.
        WHEN cl_abap_typedescr=>kind_struct.
" If it's a structure (JSON object)
          DATA(lo_structdescr) = CAST cl_abap_structdescr( lo_typedescr ).

" Handle object projection (e.g., {field1, field2})
          IF lv_path_element CS 'PROJECT:'.
            DATA(lv_fields) = substring_after( val = lv_path_element sub = 'PROJECT:' ).
            SPLIT lv_fields AT ',' INTO TABLE DATA(lt_field_names).
            LOOP AT lt_field_names INTO DATA(lv_field).
              CONDENSE lv_field. " Remove leading/trailing spaces
" Assign the component of the structure to a field symbol
              ASSIGN COMPONENT lv_field OF STRUCTURE <fs_data> TO FIELD-SYMBOL(<fs_proj_field>).
              IF <fs_proj_field> IS ASSIGNED.
" Add a reference to the projected field to the next nodes
                APPEND REF #( <fs_proj_field> ) TO lt_next_nodes.
              ENDIF.
            ENDLOOP.
          ELSE.
" Normal field access for a structure
            ASSIGN COMPONENT lv_path_element OF STRUCTURE <fs_data> TO FIELD-SYMBOL(<fs_component>).
            IF <fs_component> IS ASSIGNED.
" Add a reference to the component to the next nodes
              APPEND REF #( <fs_component> ) TO lt_next_nodes.
            ENDIF.
          ENDIF.

        WHEN cl_abap_typedescr=>kind_table.
" If it's a table (JSON array)
          DATA(lo_tabledescr) = CAST cl_abap_tabledescr( lo_typedescr ).

" Handle array slicing (e.g., [*] for all elements)
          IF lv_path_element = '*'.
            LOOP AT <fs_data> ASSIGNING FIELD-SYMBOL(<fs_line>).
" Add a reference to each line (element) of the table to the next nodes
              APPEND REF #( <fs_line> ) TO lt_next_nodes.
            ENDLOOP.
          ELSE.
" Handle array indexing (e.g., [n])
            TRY.
                DATA(lv_index) = CONV i( lv_path_element ).
                IF lv_index LT 0.
" Handle negative indices (from end of array)
                  SORT <fs_data> DESCENDING. " Sort to access from end
                  lv_index *= -1. " Make index positive
                ELSE.
                  lv_index += 1. " Convert zero-based index to one-based for ABAP table access
                ENDIF.

" Check if the index is valid
                IF lv_index GT 0 AND lv_index LE lines( <fs_data> ).
                  LOOP AT <fs_data> ASSIGNING <fs_line>.
                    IF sy-tabix EQ lv_index.
                      EXIT. " Found the element at the specified index
                    ENDIF.
                  ENDLOOP.
                  IF sy-subrc EQ 0.
" Add a reference to the found element to the next nodes
                    APPEND REF #( <fs_line> ) TO lt_next_nodes.
                  ENDIF.
                ENDIF.
              CATCH cx_sy_conversion_error.
" Not a valid index, ignore this path element for tables
            ENDTRY.
          ENDIF.
      ENDCASE.
    ENDLOOP.

" If next nodes were found, recursively navigate with the remaining path
    IF lt_next_nodes IS NOT INITIAL.
      rt_result = navigate( it_nodes = lt_next_nodes it_path = lt_remaining_path ).
    ENDIF.

  ENDMETHOD.


  METHOD parse_path.
    DATA: lv_jsonpath TYPE string, " Local copy of the JSONPath for manipulation
          lt_path     TYPE string_table, " Table to store parsed path segments
          lv_segment  TYPE string.  " Temporary variable for path segment

    lv_jsonpath = iv_jsonpath. " Initialize with the input JSONPath

    TRY.
" Transform JSONPath syntax into an internal, simpler format
" Handle object projection: {field1, field2, ...} -> PROJECT:field1,field2,...
        REPLACE ALL OCCURRENCES OF PCRE `\{([^}]+)\}` IN lv_jsonpath WITH `PROJECT:$1`.
" Handle quoted property names: ['prop'] -> .prop
        REPLACE ALL OCCURRENCES OF PCRE `\['([^']*)'\]` IN lv_jsonpath WITH `.$1`.
" Remove leading/trailing quotes around dot-separated property names
        REPLACE ALL OCCURRENCES OF PCRE `\."` IN lv_jsonpath WITH `.` .
        REPLACE ALL OCCURRENCES OF PCRE `"\."` IN lv_jsonpath WITH `.` .
" Handle array slicing: [] -> [*]
        REPLACE ALL OCCURRENCES OF `[]` IN lv_jsonpath WITH `[*]`.
" Replace '[' with '.' and remove ']' for array access
        REPLACE ALL OCCURRENCES OF `[` IN lv_jsonpath WITH `.` .
        REPLACE ALL OCCURRENCES OF `]` IN lv_jsonpath WITH `` .
" Handle array indexing: [n] -> .n
        REPLACE ALL OCCURRENCES OF PCRE `\[([0-9]+)\]` IN lv_jsonpath WITH `.$1`.
" Handle pipe operator: | -> .PIPE.
        REPLACE ALL OCCURRENCES OF ` | ` IN lv_jsonpath WITH `.PIPE.`.
        REPLACE ALL OCCURRENCES OF `|` IN lv_jsonpath WITH `.PIPE.`.
    CATCH cx_sy_invalid_regex_format.
" Breakpoint for debugging invalid regex in development
        BREAK-POINT.
    ENDTRY.

" Split the transformed JSONPath into segments based on '.'
    SPLIT lv_jsonpath AT '.' INTO TABLE lt_path.

" Remove any initial empty segments that might result from splitting (e.g., if path starts with '.')
    DELETE lt_path WHERE table_line IS INITIAL.

" If the first segment is '$' (root), remove it as it's implicit
    IF lt_path IS NOT INITIAL AND lt_path[ 1 ] = '$'.
      DELETE lt_path INDEX 1.
    ENDIF.

" Return the parsed path segments
    rt_path = lt_path.

  ENDMETHOD.

ENDCLASS.