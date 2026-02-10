#Requires AutoHotkey v2+

StrStartsWith(haystack, needle) => SubStr(haystack, 1, StrLen(needle)) == needle
StrEndsWith(haystack, needle) => SubStr(haystack, StrLen(needle), 1) == needle