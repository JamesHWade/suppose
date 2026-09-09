# chat input errors explain valid choices without invoking a provider

    Code
      inquiry_chat_factory("model-name")
    Condition
      Error in `inquiry_chat_factory()`:
      ! Supply an ellmer Chat or a function that creates one.

---

    Code
      inquiry_chat_factory(function() NULL)()
    Condition
      Error:
      ! The chat constructor must return an ellmer Chat.

---

    Code
      suppose_app(chat = function() NULL, chat_factory = function() NULL)
    Condition
      Error in `suppose_app()`:
      ! Supply only one of chat, chat_factory, or agent_factory.

---

    Code
      suppose_app(chat = function() NULL, agent_factory = function() NULL)
    Condition
      Error in `suppose_app()`:
      ! Supply only one of chat, chat_factory, or agent_factory.

---

    Code
      suppose_example_app(chat = function() NULL, chat_factory = function() NULL)
    Condition
      Error in `suppose_example_app()`:
      ! Supply chat or chat_factory, not both.

