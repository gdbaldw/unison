# Definition Summary APIs

```ucm:hide
.> builtins.mergeio
```


```unison:hide
nat : Nat
nat = 42
doc : Doc2
doc = {{ Hello }}
test> mytest = [Test.Result.Ok "ok"]
func : Text -> Text
func x = x ++ "hello"

funcWithLongType : Text -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> Text
funcWithLongType a b c d e f g h = a ++ b ++ c ++ d ++ e ++ f ++ g ++ h

structural type Thing = This Nat | That
```

```ucm:hide
.> add
```

## Term Summary APIs

```api
-- term
GET /api/definitions/terms/qualified/nat@qkhkl0n238/summary

-- doc
GET /api/definitions/terms/qualified/doc@icfnhas71n/summary

-- test
GET /api/definitions/terms/qualified/mytest@u17p9803hd/summary

-- function
GET /api/definitions/terms/qualified/func@6ee6j48hk3/summary

-- constructor
GET /api/definitions/terms/qualified/Thing.This@altimqs66j@0/summary


-- Long type signature
GET /api/definitions/terms/qualified/funcWithLongType@ieskgcjjvu/summary

-- Long type signature with render width
GET /api/definitions/terms/qualified/funcWithLongType@ieskgcjjvu/summary?renderWidth=20
```