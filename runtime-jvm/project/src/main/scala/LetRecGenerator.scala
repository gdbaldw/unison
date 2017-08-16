package org.unisonweb.codegeneration

object LetRecGenerator extends OneFileGenerator("CompileLetRec.scala") {
  def source =
    "package org.unisonweb.compilation" <>
    "" <>
    "trait CompileLetRec " + {
      "def compileLetRec(e: TermC, bindings: Array[Computation], body: Computation): Computation = " + {
        "(stackSize(e): @annotation.switch) match " + {
           (0 to maxInlineStack).each { i =>
             s"case $i => (bindings.length: @annotation.switch) match " + {
               (1 to maxInlineArgs).each { j =>
                 s"case $j => " <> {
                   s"class LetRecS${i}A${j} extends Computation$i(e, ()) " + {
                     (1 to j).each { k => s"val b$k = bindings(${k-1})" } <>
                     applySignature(i) + " = " + {
                       val bArgs =
                        if (i + j <= maxInlineStack)
                          (j to 1 by -1).commas(l => s"0.0, b${l}r") + commaIf(i) +
                          (0 until i).commas(l => s"x$l, x${l}b")
                        else
                          "Array(" +
                            (j to 1 by -1).commas(l => s"Slot(0.0, b${l}r)") + commaIf(i) +
                            (0 until i).commas(l => s"Slot(x$l, x${l}b)") +
                          ")"
                       "val " + (1 to j).commas { k => s"b${k}r" } + " = Ref()" <>
                       (1 to j).each { k => s"b${k}r.value = Value(" + catchTC(s"b$k(rec, $bArgs, r)") + ", r.boxed)" } <>
                       s"body(rec, $bArgs, r)"
                     }.b
                   }.b <>
                   s"new LetRecS${i}A${j}"
                 }.indent
               } <>
               "case n => " <> {
                 s"class LetRecS${i}AN extends Computation$i(e, ()) " + {
                   applySignature(i) + " = " + {
                     "val refs = Array.fill(bindings.length)(Ref())" <>
                     "val xs = Array[Slot](" + (0 until i).commas(k => s"Slot(x$k,x${k}b)") + ")" <>
                     "val slots = refs.view.map(r => Slot(0.0, r)).reverse.toArray ++ xs" <>
                     "var i = 0" <>
                     "while (i < bindings.length)" + {
                       "refs(i).value = Value(" + catchTC("bindings(i)(rec, slots, r)") + ", r.boxed)" <>
                       "i += 1"
                     }.b <>
                     "body(rec, slots, r)"
                   }.b
                 }.b <>
                 s"new LetRecS${i}AN"
               }.indent
             }.b
           } <>
           "case n => " <> {
             s"class LetRecSNAN extends ComputationN(n, e, ()) " + {
               applyNSignature + " = " + {
                 "val refs = Array.fill(bindings.length)(Ref())" <>
                 "val slots = refs.view.map(r => Slot(0.0, r)).reverse.toArray ++ xs" <>
                 "var i = 0" <>
                 "while (i < bindings.length)" + {
                   "refs(i).value = Value(" + catchTC("bindings(i)(rec, slots, r)") + ", r.boxed)" <>
                   "i += 1"
                 }.b <>
                 "body(rec, slots, r)"
               }.b
             }.b <>
             "new LetRecSNAN"
           }.indent
        }.b
      }.b
    }.b
}
