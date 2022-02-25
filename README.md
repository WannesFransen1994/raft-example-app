# RaftExampleApp

Start with `iex -S mix`

Test manually with Telnet. Later on a sample client will be introduced for easier visualisation.

```text
$ telnet localhost 4200
login wannes
<<noreply here>>
UP IN
<<starts moving upwards>>
UP OUT
<<stops>>

UP IN
...
LEFT IN
<<this movement is ignored for now. One movement direction at a time>>
UP OUT
<<stops moving>>
```
