{% macro ensure_nonclustered_index(relation, index_name, columns, included_columns=[]) %}
    if object_id('{{ relation.schema }}.{{ relation.identifier }}', 'U') is not null
       and not exists (
           select 1
           from sys.indexes
           where object_id = object_id('{{ relation.schema }}.{{ relation.identifier }}')
             and name = '{{ index_name }}'
       )
    begin
        create nonclustered index [{{ index_name }}]
            on {{ relation }} (
                {%- for column in columns -%}
                    [{{ column }}]{{ ", " if not loop.last }}
                {%- endfor -%}
            )
            {%- if included_columns %}
            include (
                {%- for column in included_columns -%}
                    [{{ column }}]{{ ", " if not loop.last }}
                {%- endfor -%}
            )
            {%- endif %};
    end
{% endmacro %}
