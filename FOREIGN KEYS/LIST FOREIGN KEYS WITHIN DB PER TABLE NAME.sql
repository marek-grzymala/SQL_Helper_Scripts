SELECT  OBJECT_NAME(f.object_id) as ForeignKeyConstraintName,
        OBJECT_NAME(f.parent_object_id) TableName,
        COL_NAME(fk.parent_object_id,fk.parent_column_id) ColumnName,
        OBJECT_NAME(fk.referenced_object_id) as ReferencedTableName,
        COL_NAME(fk.referenced_object_id,fk.referenced_column_id) as ReferencedColumnName

FROM sys.foreign_keys AS f
    INNER JOIN sys.foreign_key_columns AS fk 
        ON f.OBJECT_ID = fk.constraint_object_id
    INNER JOIN sys.tables t
        ON fk.referenced_object_id = t.object_id

WHERE    OBJECT_NAME(fk.referenced_object_id) = 'your table name'
AND      COL_NAME(fk.referenced_object_id,fk.referenced_column_id) = 'your key column name'