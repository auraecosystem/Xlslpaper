program     := statement*

statement   := subject
             | object
             | directive
             | assignment
             | comment

subject     := "subject" identifier

object      := "object" identifier "{" object_body* "}"

directive   := deep_directive
             | create_directive
             | execute_directive

deep_directive
            := "^↑D" block

create_directive
            := "^D" block

execute_directive
            := "^|D" block

block       := "{" operation* "}"

operation   := identifier
             | identifier identifier
             | identifier string

assignment  := identifier "=" value

value       := string
             | number
             | boolean
             | identifier

comment     := "#" text
