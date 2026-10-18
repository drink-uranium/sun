#!/usr/bin/env python3
# ========== Copyright Header Begin ==========================================
#
# OpenBoot x86 port: stage-0 metacompiler
#
# Copyright (c) 2026 The OpenBoot x86 port contributors.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted under the same terms as the rest of
# OpenBoot (see the copyright header of any OpenBoot source file).
#
# ========== Copyright Header End ============================================
"""
meta86 -- stage-0 metacompiler for the x86 port of OpenBoot.

OpenBoot's kernel (forth.dic) is normally built by its own metacompiler
(obp/fm/meta/*.fth) running inside an already-working OpenBoot Forth on the
build host.  The only such host Forth that ships with OpenBoot is a SPARC
Solaris binary (bin/forth), so it cannot be used to build an x86 kernel.

meta86 breaks that chicken-and-egg problem.  It is a re-implementation, in
Python, of the semantics of obp/fm/meta (target.fth, compilin.fth,
forward.fth, meta1.fth): it reads the very same kernel load file and kernel
sources (obp/fm/kernel/*.fth plus the x86-specific obp/fm/kernel/x86/*.fth),
builds the target dictionary with exactly the header, vocabulary, user-area
and code-field layout that the target kernel expects, and writes it out as a
GNU assembler source file.  Target `code' words are written in AT&T syntax
x86 assembler, the way the SPARC kernel's code words are written in the
SPARC assembler.  The assembler/linker then produce kernel.dic, a memory
image that is loaded at a fixed origin.

Once kernel.dic runs (under the Linux wrapper, obp/os/unix/x86), everything
else -- the Forth tools, the Open Firmware core, the device tree and the PC
platform support -- is compiled natively by the x86 OpenBoot itself, exactly
as the SPARC build does with its forth.dic.

Usage:  meta86.py [-D sym]... [-I bp] -o kernel.S loadfile.fth
"""

import os
import re
import sys

MASK = 0xffffffff


def s32(v):
    v &= MASK
    return v - (1 << 32) if v & 0x80000000 else v


class MetaError(Exception):
    pass


class Sym(object):
    """A target-dictionary symbol (the metacompiler's `symbols' entry)."""

    def __init__(self, name, label):
        self.name = name
        self.label = label
        self.kind = None
        self.defined = False
        self.immediate = False
        self.flags_idx = None
        self.flags_val = 0
        self.user = None
        self.value = None
        self.value_idx = None
        self.voc = None
        self.has_header = False
        self.prev = None

    def __repr__(self):
        return '<Sym %s %s>' % (self.name, self.label)


class Voc(object):
    def __init__(self, name, words):
        self.name = name
        self.words = words
        self.user = None
        self.sym = None


class HostCell(object):
    """A host (metacompiler) variable.  `@' and `!' work on these."""

    def __init__(self, name, value=0):
        self.name = name
        self.value = value


class HostString(object):
    def __init__(self, s):
        self.s = s


class Source(object):
    def __init__(self, name, text):
        self.name = name
        self.lines = text.split('\n')
        self.lineno = 0
        self.pos = 0

    def line(self):
        if self.lineno < len(self.lines):
            return self.lines[self.lineno]
        return None


def gas_expr(v):
    if isinstance(v, int):
        return str(s32(v))
    if isinstance(v, Sym):
        return v.label
    if isinstance(v, str):
        return v
    raise MetaError('cannot use %r as a target value' % (v,))


def add(a, b):
    if isinstance(a, int) and isinstance(b, int):
        return s32(a + b)
    if isinstance(b, int) and b == 0:
        return a
    if isinstance(a, int) and a == 0:
        return b
    return '(%s+%s)' % (gas_expr(a), gas_expr(b))


def sub(a, b):
    if isinstance(a, int) and isinstance(b, int):
        return s32(a - b)
    if isinstance(b, int) and b == 0:
        return a
    return '(%s-%s)' % (gas_expr(a), gas_expr(b))


def mangle(name):
    out = []
    for c in name:
        if c.isalnum() or c == '_':
            out.append(c)
        else:
            out.append('_%02x' % ord(c))
    return 'f_' + ''.join(out)


class Meta(object):

    CONFIG = {
        '16\\': False, '32\\': True, '64\\': False,
        '\\t8': False, '\\t16': False, '\\t32': True,
        '\\itc': True, '\\dtc': False, '\\ttc': False,
    }

    def __init__(self, bp, defines):
        self.bp = bp
        self.defines = set(d.lower() for d in defines)
        self.sources = []
        self.stack = []
        self.state = 'interp'         # 'interp' | 'meta' | 'code'
        self.base = 10
        self.out = ['\t.globl origin', 'origin:']
        self.prologue = []
        self.nlabel = 0
        self.symbols = {}
        self.labels = {}              # equ's, mlabels, target constants
        self.labelnames = set()
        self.header_control = 0       # -1 never, 0 always, 1 yes, 2 no
        self.lastacf = None
        self.user_image = {}
        self.user_size = 0x10000
        self.vocabs = []
        self.threads_t = []           # words defined before "forth" exists
        self.current_t = self.threads_t
        self.context_t = None
        self.voc_link = 'origin'
        self.doestarget = None
        self.code_first = False
        self.code_sym = None
        self.cs_marks = []
        self.csp = None
        self.colon_sym = None
        self.hidden_sym = None
        self.cells = {
            '#user-t': HostCell('#user-t', 0),
            'voc-link-t': HostCell('voc-link-t', 'origin'),
            'warning-t': HostCell('warning-t', 0),
            'threshold': HostCell('threshold', 0),
            'show?': HostCell('show?', 0),
            'granularity': HostCell('granularity', 0),
        }
        self.files_loaded = []
        self.init_words()

    # ------------------------------------------------------------------
    # Input handling

    def error(self, msg):
        where = ''
        if self.sources:
            s = self.sources[-1]
            where = '%s:%d: ' % (s.name, s.lineno + 1)
        raise MetaError(where + msg)

    def warn(self, msg):
        where = ''
        if self.sources:
            s = self.sources[-1]
            where = '%s:%d: ' % (s.name, s.lineno + 1)
        sys.stderr.write('meta86: %swarning: %s\n' % (where, msg))

    def expand(self, path):
        def rep(m):
            name = m.group(1) or m.group(2)
            if name == 'BP':
                return self.bp
            v = os.environ.get(name)
            if v is None:
                self.error('undefined environment variable %s' % name)
            return v
        return re.sub(r'\$\{(\w+)\}|\$(\w+)', rep, path)

    def include(self, path):
        path = self.expand(path)
        if not os.path.isabs(path) and self.sources:
            cand = os.path.join(os.path.dirname(self.sources[-1].name), path)
            if os.path.exists(cand):
                path = cand
        try:
            with open(path, 'r', encoding='latin-1') as f:
                text = f.read()
        except IOError as e:
            self.error('cannot open %s: %s' % (path, e))
        self.files_loaded.append(path)
        self.sources.append(Source(path, text))

    def evaluate(self, text, name='<evaluate>'):
        self.sources.append(Source(name, text))
        depth = len(self.sources)
        while len(self.sources) >= depth:
            w = self.word(limit=depth)
            if w is None:
                break
            self.do_word(w)
        if len(self.sources) >= depth:
            self.sources.pop()

    def word(self, limit=1):
        """Parse the next blank-delimited word, crossing lines and files."""
        while len(self.sources) >= limit and self.sources:
            s = self.sources[-1]
            line = s.line()
            if line is None:
                if len(self.sources) == limit and limit > 1:
                    return None
                self.sources.pop()
                continue
            n = len(line)
            i = s.pos
            while i < n and line[i] <= ' ':
                i += 1
            if i >= n:
                s.lineno += 1
                s.pos = 0
                continue
            j = i
            while j < n and line[j] > ' ':
                j += 1
            s.pos = j + 1 if j < n else j
            return line[i:j]
        return None

    def parse(self, delim):
        """Forth `parse': text up to delim on the current line."""
        s = self.sources[-1]
        line = s.line() or ''
        i = s.pos
        j = line.find(delim, i)
        if j < 0:
            s.pos = len(line)
            return line[i:]
        s.pos = j + 1
        return line[i:j]

    def rest_of_line(self):
        s = self.sources[-1]
        line = s.line() or ''
        text = line[s.pos:]
        s.lineno += 1
        s.pos = 0
        return text

    def skip_line(self):
        s = self.sources[-1]
        line = s.line() or ''
        s.pos = len(line)

    def paren_comment(self):
        """`(' comments may span lines when loading files."""
        while self.sources:
            s = self.sources[-1]
            line = s.line()
            if line is None:
                return
            j = line.find(')', s.pos)
            if j >= 0:
                s.pos = j + 1
                return
            s.lineno += 1
            s.pos = 0

    def safe_word(self):
        w = self.word()
        if w is None:
            self.error('unexpected end of input')
        return w

    # ------------------------------------------------------------------
    # Numbers (Forthmacs $dnumber? semantics, singles only)

    def number(self, w, base=None):
        if base is None:
            base = self.base
        s = w
        neg = False
        if s.startswith('-') and len(s) > 1:
            neg = True
            s = s[1:]
        if not s:
            return None
        val = 0
        ndig = 0
        i = 0
        while i < len(s):
            c = s[i].lower()
            if c.isdigit():
                d = ord(c) - ord('0')
            elif 'a' <= c <= 'z':
                d = ord(c) - ord('a') + 10
            else:
                d = 99
            if d < base:
                val = val * base + d
                ndig += 1
                i += 1
                continue
            if c in '.,' and i + 1 < len(s) and ndig:
                i += 1
                continue
            if c == '.' and i + 1 == len(s) and ndig:
                # A trailing period makes a double number
                return ('double', -val if neg else val)
            return None
        if not ndig:
            return None
        if neg:
            val = -val
        return s32(val)

    # ------------------------------------------------------------------
    # Host stack

    def push(self, v):
        self.stack.append(v)

    def pop(self):
        if not self.stack:
            self.error('host stack underflow')
        return self.stack.pop()

    def popint(self):
        v = self.pop()
        if isinstance(v, HostString):
            self.error('expected a number, got a string')
        return v

    # ------------------------------------------------------------------
    # Target image emission

    def emit(self, line):
        self.out.append(line)
        return len(self.out) - 1

    def newlabel(self, prefix='L'):
        self.nlabel += 1
        return '.%s%d' % (prefix, self.nlabel)

    def here(self):
        lab = self.newlabel('H')
        self.emit('%s:' % lab)
        return lab

    def t_long(self, v):
        self.emit('\t.long %s' % gas_expr(v))

    def t_short(self, v):
        self.emit('\t.short %s' % gas_expr(v))

    def t_byte(self, v):
        self.emit('\t.byte %s' % gas_expr(v))

    def t_align(self):
        self.emit('\t.p2align 2,0')

    def t_bytes(self, data):
        for i in range(0, len(data), 16):
            chunk = data[i:i + 16]
            self.emit('\t.byte ' + ','.join(str(b) for b in chunk))

    def t_string(self, text):
        """Inline counted string, null terminated, token aligned."""
        data = text.encode('latin-1')
        if len(data) > 255:
            self.error('string too long')
        self.t_bytes(bytes([len(data)]) + data + b'\0')
        self.t_align()

    # ------------------------------------------------------------------
    # Symbols and headers

    def sym_lookup(self, name):
        s = self.symbols.get(name.lower())
        if s is not None and s is self.hidden_sym:
            return s.prev
        return s

    def new_label_for(self, name):
        base = mangle(name)
        lab = base
        n = 1
        while lab in self.labelnames:
            n += 1
            lab = '%s_%d' % (base, n)
        self.labelnames.add(lab)
        return lab

    def forward(self, name):
        """Create (or find) an unresolved symbol for a forward reference."""
        name = name.lower()
        s = self.symbols.get(name)
        if s is None:
            s = Sym(name, self.new_label_for(name))
            s.prev = None
            self.symbols[name] = s
        return s

    def make_header(self, name, kind):
        name = name.lower()
        old = self.symbols.get(name)
        if old is not None and not old.defined:
            s = old            # resolve the forward reference
        else:
            s = Sym(name, self.new_label_for(name))
            s.prev = old
            self.symbols[name] = s
        s.kind = kind
        make = self.header_control in (0, 1)
        if make:
            data = name.encode('latin-1')
            if len(data) > 31:
                self.error('name too long: %s' % name)
            self.t_align()
            pad = (-(len(data) + 1 + 4)) % 4
            if pad:
                self.emit('\t.fill %d,1,0' % pad)
            if data:
                self.t_bytes(data)
            s.flags_val = 0x80 | len(data)
            s.flags_idx = self.emit('\t.byte %d' % s.flags_val)
            self.emit('\t.long .LK_%s' % s.label)
            self.current_t.append(s)
            s.has_header = True
        else:
            self.t_align()
        self.emit('\t.globl %s' % s.label)
        self.emit('%s:' % s.label)
        s.defined = True
        self.lastacf = s
        return s

    def set_immediate(self):
        s = self.lastacf
        if s is None:
            self.error('immediate with no word')
        s.immediate = True
        if s.flags_idx is not None:
            s.flags_val |= 0x40
            self.out[s.flags_idx] = '\t.byte %d' % s.flags_val

    def place_cf(self, action):
        """Code field of a non-code word: a token for the action code."""
        self.t_long(self.target_ref(action))

    def target_ref(self, name):
        """Address of a target word or label, for use in the image."""
        if name in self.labels:
            return self.labels[name]
        return self.forward(name)

    def compile_token(self, s):
        self.t_long(s)

    def compile_name(self, name):
        s = self.sym_lookup(name)
        if s is None:
            s = self.forward(name)
        self.compile_token(s)

    def literal(self, v):
        if isinstance(v, tuple) and v[0] == 'double':
            d = v[1]
            self.compile_name('(dlit)')
            self.t_long(s32(d))
            self.t_long(-1 if d < 0 else 0)
            return
        self.compile_name('(lit)')
        self.t_long(v)

    def ualloc(self, n):
        cell = self.cells['#user-t']
        u = cell.value
        if n >= 4:
            u = (u + 3) & ~3
            cell.value = u
        cell.value = u + n
        if cell.value > self.user_size:
            self.error('user area overflow')
        return u

    def set_user(self, offset, value):
        self.user_image[offset] = value

    def user_word(self, name, offset, kind='user'):
        s = self.make_header(name, kind)
        self.place_cf('douser')
        self.t_long(offset)
        s.user = offset
        return s

    # ------------------------------------------------------------------
    # The main loop

    def run(self):
        while self.sources:
            if self.state == 'code':
                if not self.sources:
                    break
                self.code_line()
                continue
            w = self.word()
            if w is None:
                break
            self.do_word(w)

    def do_word(self, w):
        lw = w.lower()
        if self.state == 'meta':
            f = self.transition.get(lw)
            if f is not None:
                f()
                return
            s = self.sym_lookup(lw)
            if s is not None:
                self.compile_token(s)
                return
            if lw in self.labels:
                self.literal(self.labels[lw])
                return
            n = self.number(w)
            if n is not None:
                self.literal(n)
                return
            self.compile_token(self.forward(lw))
            return
        if self.state == 'code':
            self.error('word in code state')
        f = self.metawords.get(lw)
        if f is not None:
            f()
            return
        if lw in self.labels:
            self.push(self.labels[lw])
            return
        n = self.number(w)
        if n is not None:
            if isinstance(n, tuple):
                self.push(s32(n[1]))
                self.push(-1 if n[1] < 0 else 0)
            else:
                self.push(n)
            return
        self.error('%s ?' % w)

    # ------------------------------------------------------------------
    # Code words: AT&T assembler text

    COND_PREFIXES = ('16\\', '32\\', '64\\', '\\t8', '\\t16', '\\t32',
                     '\\itc', '\\dtc', '\\ttc')

    def enter_code(self, sym=None):
        self.state = 'code'
        self.code_first = True
        self.code_sym = sym

    def subst(self, text):
        def rep(m):
            depth = len(self.stack)
            self.state = 'interp'
            self.evaluate(m.group(1), '<code-expression>')
            self.state = 'code'
            if len(self.stack) != depth + 1:
                self.error('code expression {%s} must leave one value'
                           % m.group(1))
            return gas_expr(self.pop())
        return re.sub(r'\{([^}]*)\}', rep, text)

    def code_line(self):
        s = self.sources[-1]
        if s.line() is None:
            self.sources.pop()
            return
        text = self.rest_of_line()
        stripped = text.strip()
        tok = stripped.split(None, 1)
        if tok and tok[0] in self.COND_PREFIXES:
            if not self.CONFIG[tok[0]]:
                self.code_first = False
                return
            text = tok[1] if len(tok) > 1 else ''
        # Forth comments: a backslash followed by white space
        m = re.search(r'(^|\s)\\(\s|$)', text)
        if m:
            text = text[:m.start()]
        if self.code_first:
            self.code_first = False
            t = text.lstrip()
            if t.startswith('( ') or t == '(' or t.startswith('(s '):
                j = t.find(')')
                text = t[j + 1:] if j >= 0 else ''
        toks = text.split()
        term = None
        if toks and toks[-1].lower() in ('c;', 'end-code'):
            term = toks[-1].lower()
            text = text[:text.rfind(toks[-1])]
        if text.strip():
            self.emit('\t' + self.subst(text.strip()))
        if term == 'c;':
            self.emit('\tNEXT')
        if term:
            self.state = 'interp'
            self.code_sym = None

    # ------------------------------------------------------------------
    # Conditional compilation

    IF_WORDS = ('[if]', '[ifdef]', '[ifndef]', '[ifexist]', '[ifnexist]')

    def skip_cond(self):
        """Skip words until the matching [else] or [then]."""
        depth = 0
        while True:
            w = self.word()
            if w is None:
                self.error('unterminated [if]')
            lw = w.lower()
            if lw in ('\\',) or lw in self.COND_PREFIXES:
                self.skip_line()
            elif lw in ('(', '(s'):
                self.paren_comment()
            elif lw in self.IF_WORDS:
                depth += 1
            elif lw == '[else]':
                if depth == 0:
                    return
            elif lw == '[then]':
                if depth == 0:
                    return
                depth -= 1

    def skip_to_then(self):
        depth = 0
        while True:
            w = self.word()
            if w is None:
                self.error('unterminated [else]')
            lw = w.lower()
            if lw in ('\\',) or lw in self.COND_PREFIXES:
                self.skip_line()
            elif lw in ('(', '(s'):
                self.paren_comment()
            elif lw in self.IF_WORDS:
                depth += 1
            elif lw == '[then]':
                if depth == 0:
                    return
                depth -= 1

    def cond(self, flag):
        if not flag:
            self.skip_cond()

    def meta_defined(self, name):
        s = self.symbols.get(name.lower())
        if s is not None and s.defined:
            return True
        return name.lower() in self.labels

    # ------------------------------------------------------------------
    # Word tables

    def init_words(self):
        m = {}
        t = {}
        self.metawords = m
        self.transition = t

        # -- words that are the same in both states
        def comment_line():
            self.skip_line()

        def paren():
            self.paren_comment()

        def dot_paren():
            sys.stderr.write(self.parse(')'))

        for k, active in self.CONFIG.items():
            def mk(active=active):
                def f():
                    if not active:
                        self.skip_line()
                return f
            m[k] = t[k] = mk()
            if k.startswith('\\'):
                m[k + '-t'] = t[k + '-t'] = mk()
        for k in ('\\', ):
            m[k] = t[k] = comment_line
        for k in ('(', '(s'):
            m[k] = t[k] = paren
        m['.('] = t['.('] = dot_paren
        for k in ('id:', 'purpose:', 'copyright:'):
            m[k] = t[k] = comment_line

        def w_if():
            self.cond(self.popint() not in (0, False))

        def w_ifdef():
            self.cond(self.safe_word().lower() in self.defines)

        def w_ifndef():
            self.cond(self.safe_word().lower() not in self.defines)

        def w_ifexist():
            self.cond(self.meta_defined(self.safe_word()))

        def w_ifnexist():
            self.cond(not self.meta_defined(self.safe_word()))

        def w_else():
            self.skip_to_then()

        def w_then():
            pass

        def w_define():
            self.defines.add(self.safe_word().lower())

        def w_undef():
            self.defines.discard(self.safe_word().lower())

        for k, f in (('[if]', w_if), ('[ifdef]', w_ifdef),
                     ('[ifndef]', w_ifndef), ('[ifexist]', w_ifexist),
                     ('[ifnexist]', w_ifnexist), ('[else]', w_else),
                     ('[then]', w_then), ('[define]', w_define),
                     ('[undef]', w_undef)):
            m[k] = t[k] = f

        # -- host Forth words (interpret state)
        def binop(fn):
            def f():
                b = self.pop()
                a = self.pop()
                self.push(fn(a, b))
            return f

        def need_int(*vals):
            for v in vals:
                if not isinstance(v, int):
                    self.error('symbolic value in host arithmetic')

        def iop(fn):
            def f():
                b = self.pop()
                a = self.pop()
                need_int(a, b)
                self.push(s32(fn(a, b)))
            return f

        def unop(fn):
            def f():
                a = self.pop()
                need_int(a)
                self.push(s32(fn(a)))
            return f

        def flag(b):
            return -1 if b else 0

        m['+'] = binop(add)
        m['-'] = binop(sub)
        m['*'] = iop(lambda a, b: a * b)
        m['/'] = iop(lambda a, b: int(a / b) if (a < 0) != (b < 0)
                     else a // b)
        m['mod'] = iop(lambda a, b: a % b)
        m['and'] = iop(lambda a, b: a & b)
        m['or'] = iop(lambda a, b: a | b)
        m['xor'] = iop(lambda a, b: a ^ b)
        m['<<'] = m['lshift'] = iop(lambda a, b: (a & MASK) << b)
        m['>>'] = m['rshift'] = iop(lambda a, b: (a & MASK) >> b)
        m['='] = binop(lambda a, b: flag(a == b))
        m['<>'] = binop(lambda a, b: flag(a != b))
        m['<'] = iop(lambda a, b: flag(a < b))
        m['>'] = iop(lambda a, b: flag(a > b))
        m['u<'] = iop(lambda a, b: flag((a & MASK) < (b & MASK)))
        m['u>'] = iop(lambda a, b: flag((a & MASK) > (b & MASK)))
        m['min'] = iop(min)
        m['max'] = iop(max)
        m['negate'] = unop(lambda a: -a)
        m['invert'] = unop(lambda a: ~a)
        m['abs'] = unop(abs)
        m['1+'] = lambda: self.push(add(self.pop(), 1))
        m['1-'] = lambda: self.push(sub(self.pop(), 1))
        m['2*'] = unop(lambda a: a * 2)
        m['2/'] = unop(lambda a: a >> 1)
        m['0='] = unop(lambda a: flag(a == 0))
        m['0<'] = unop(lambda a: flag(a < 0))
        m['0<>'] = unop(lambda a: flag(a != 0))

        def dup():
            v = self.pop()
            self.push(v)
            self.push(v)
        m['dup'] = dup
        m['drop'] = lambda: self.pop()

        def swap():
            b = self.pop()
            a = self.pop()
            self.push(b)
            self.push(a)
        m['swap'] = swap

        def over():
            self.push(self.stack[-2])
        m['over'] = over

        def rot():
            c = self.pop()
            b = self.pop()
            a = self.pop()
            self.stack += [b, c, a]
        m['rot'] = rot

        def mrot():
            c = self.pop()
            b = self.pop()
            a = self.pop()
            self.stack += [c, a, b]
        m['-rot'] = mrot

        def nip():
            b = self.pop()
            self.pop()
            self.push(b)
        m['nip'] = nip

        def tuck():
            b = self.pop()
            a = self.pop()
            self.stack += [b, a, b]
        m['tuck'] = tuck

        def twodup():
            self.stack += self.stack[-2:]
        m['2dup'] = twodup

        def twodrop():
            self.pop()
            self.pop()
        m['2drop'] = twodrop

        def qdup():
            v = self.stack[-1]
            if v != 0:
                self.push(v)
        m['?dup'] = qdup

        m['true'] = lambda: self.push(-1)
        m['false'] = lambda: self.push(0)

        def setbase(b):
            def f():
                self.base = b
            return f
        m['hex'] = setbase(16)
        m['decimal'] = setbase(10)
        m['octal'] = setbase(8)
        m['binary'] = setbase(2)

        def num_prefix(b):
            def f():
                w = self.safe_word()
                n = self.number(w, b)
                if n is None or isinstance(n, tuple):
                    self.error('bad number %s' % w)
                if self.state == 'meta':
                    self.literal(n)
                else:
                    self.push(n)
            return f
        for k, b in (('h#', 16), ('th', 16), ('d#', 10), ('td', 10),
                     ('o#', 8), ('b#', 2)):
            m[k] = t[k] = num_prefix(b)

        def ascii_w():
            c = ord(self.safe_word()[0])
            if self.state == 'meta':
                self.literal(c)
            else:
                self.push(c)
        m['ascii'] = m['char'] = m['[char]'] = ascii_w
        t['ascii'] = t['[char]'] = ascii_w

        def control_w():
            c = ord(self.safe_word()[0]) & 0x1f
            if self.state == 'meta':
                self.literal(c)
            else:
                self.push(c)
        m['control'] = t['control'] = control_w

        def fetch():
            a = self.pop()
            if not isinstance(a, HostCell):
                self.error('@ of a non-host address')
            self.push(a.value)
        m['@'] = m['l@'] = m['link-t@'] = m['a-t@'] = fetch

        def store():
            a = self.pop()
            v = self.pop()
            if not isinstance(a, HostCell):
                self.error('! to a non-host address')
            a.value = v
        m['!'] = m['l!'] = store

        def plusstore():
            a = self.pop()
            v = self.pop()
            a.value = add(a.value, v)
        m['+!'] = plusstore

        def on():
            self.pop().value = -1

        def off():
            self.pop().value = 0
        m['on'] = on
        m['off'] = off
        for name, cell in self.cells.items():
            m[name] = (lambda cell=cell: self.push(cell))

        def dot():
            sys.stderr.write('%s ' % (self.pop(),))
        m['.'] = dot
        m['cr'] = lambda: sys.stderr.write('\n')

        def dotquote():
            s = self.parse('"')
            if self.state == 'meta':
                self.compile_name('(.")')
                self.t_string(s)
            else:
                sys.stderr.write(s)
        m['."'] = dotquote

        def abortquote():
            s = self.parse('"')
            if self.state == 'meta':
                self.compile_name('(abort")')
                self.t_string(s)
            else:
                if self.pop():
                    self.error(s)
        m['abort"'] = abortquote

        def quote():
            s = self.parse('"')
            if self.state == 'meta':
                self.compile_name('(")')
                self.t_string(s)
            else:
                self.push(HostString(s))
        m['"'] = quote

        def pquote():
            s = self.parse('"')
            self.compile_name('("s)')
            self.t_string(s)

        def fload():
            self.include(self.safe_word())
        m['fload'] = m['fl'] = m['include'] = fload

        def noop():
            pass
        for k in ('only', 'also', 'previous', 'definitions', 'transient',
                  'resident', 'meta', 'labels', 'symbols', 'assembler',
                  'meta-compile', 'meta-assemble', 'extend-meta-assembler',
                  'forth-h', 'metaon', 'metaoff', 'caps', 'warning',
                  'xref-on', 'xref-off', 'forth', 'root'):
            m[k] = noop

        def round_up():
            g = self.popint()
            n = self.popint()
            self.push((n + g - 1) & ~(g - 1))
        m['round-up'] = round_up

        # -- header control
        def headerless():
            if self.header_control > 0:
                self.header_control = 2

        def headers():
            if self.header_control > 0:
                self.header_control = 1
        m['headerless'] = headerless
        m['headers'] = headers
        m['always-headers'] = lambda: setattr(self, 'header_control', 0)
        m['sometimes-headers'] = lambda: setattr(self, 'header_control', 1)
        m['never-headers'] = lambda: setattr(self, 'header_control', -1)

        # -- metacompiler data words
        m['/n-t'] = m['/n'] = m['/l-t'] = m['/l'] = lambda: self.push(4)
        m['/a-t'] = m['/a'] = m['/token-t'] = m['/token'] = \
            m['/link-t'] = m['/link'] = lambda: self.push(4)
        m['/w-t'] = m['/w'] = lambda: self.push(2)
        m['/c-t'] = m['/c'] = lambda: self.push(1)
        m['/x-t'] = lambda: self.push(8)
        m['#threads-t'] = lambda: self.push(1)
        m['#talign-t'] = m['#talign'] = lambda: self.push(4)
        m['#align-t'] = lambda: self.push(4)
        m['#acf-align-t'] = lambda: self.push(4)
        m['/defer-t'] = lambda: self.push(4)
        m['user-size-t'] = lambda: self.push(self.user_size)
        m['origin-t'] = m['origin'] = lambda: self.push('origin')
        m['here-t'] = m['here'] = lambda: self.push(self.here())
        m['lastacf-t'] = lambda: self.push(self.lastacf)

        def comma():
            self.t_long(self.pop())
        m[','] = m[',-t'] = m['l,'] = m['l,-t'] = m['token,-t'] = \
            m['a,-t'] = m['link,-t'] = comma
        m['w,'] = m['w,-t'] = lambda: self.t_short(self.pop())
        m['c,'] = m['c,-t'] = lambda: self.t_byte(self.pop())

        def allot():
            n = self.popint()
            if n:
                self.emit('\t.fill %d,1,0' % n)
        m['allot'] = m['allot-t'] = allot
        m['align'] = m['align-t'] = m['acf-align-t'] = m['talign-t'] = \
            m['linkalign-t'] = self.t_align

        def body_t():
            self.push(add(self.pop(), 4))
        m['>body-t'] = m['>body'] = body_t

        def ualloc_t():
            self.push(self.ualloc(self.popint()))
        m['ualloc-t'] = ualloc_t

        def ualigned_t():
            self.push((self.popint() + 3) & ~3)
        m['ualigned-t'] = ualigned_t

        def gas_set_user_size():
            self.user_size = self.popint()
        m['set-user-size-t'] = gas_set_user_size

        # -- labels and equates
        def equ():
            name = self.safe_word().lower()
            self.labels[name] = self.pop()
        m['equ'] = equ

        def mlabel_named(name, align=True):
            if align:
                self.t_align()
            lab = self.new_label_for(name)
            self.emit('\t.globl %s' % lab)
            self.emit('%s:' % lab)
            self.labels[name.lower()] = lab
            return lab

        def mlabel():
            mlabel_named(self.safe_word())
        m['mlabel'] = mlabel

        def mloclabel():
            mlabel_named(self.safe_word(), align=False)
        m['mloclabel'] = mloclabel

        def code_field():
            mlabel_named(self.safe_word())
            self.enter_code()
        m['code-field:'] = code_field

        def gas_prologue():
            # Lines up to "end-prologue" go verbatim to the head of the
            # assembler output (macro definitions and the like).
            self.rest_of_line()
            while True:
                s = self.sources[-1]
                line = s.line()
                if line is None:
                    self.error('missing end-prologue')
                s.lineno += 1
                s.pos = 0
                if line.strip().lower() == 'end-prologue':
                    return
                self.prologue.append(line)
        m['gas-prologue'] = gas_prologue

        # -- defining words
        def colon():
            name = self.safe_word()
            self.csp = len(self.stack)
            s = self.make_header(name, 'colon')
            self.place_cf('docolon')
            self.hidden_sym = s
            self.colon_sym = s
            self.state = 'meta'
        m[':'] = colon

        def chain_colon(chain):
            name = self.safe_word()
            prev = self.sym_lookup(name)
            if prev is not None and not prev.defined:
                self.error('%s must exist!' % name)
            hc = self.header_control
            if hc:
                headerless()
            self.csp = len(self.stack)
            s = self.make_header(name, 'colon')
            self.place_cf('docolon')
            self.hidden_sym = s
            self.colon_sym = s
            self.state = 'meta'
            if chain and prev is not None:
                self.compile_token(prev)
            self.header_control = hc
        m['chain:'] = lambda: chain_colon(True)
        m['overload:'] = lambda: chain_colon(False)

        def code():
            name = self.safe_word()
            s = self.make_header(name, 'code')
            self.t_long('%s+4' % s.label)
            self.enter_code(s)
        m['code'] = code

        def label():
            name = self.safe_word()
            s = self.make_header(name, 'label')
            self.place_cf('dolabel')
            self.t_align()
            self.labels[name.lower()] = '%s+4' % s.label
            self.enter_code(s)
        m['label'] = label

        def constant():
            name = self.safe_word()
            v = self.pop()
            self.labels[name.lower()] = v
            s = self.make_header(name, 'constant')
            self.place_cf('doconstant')
            s.value = v
            s.value_idx = self.emit('\t.long %s' % gas_expr(v))
        m['constant'] = constant

        def two_constant():
            name = self.safe_word()
            hi = self.pop()
            lo = self.pop()
            s = self.make_header(name, '2constant')
            self.place_cf('do2constant')
            self.t_long(lo)
            self.t_long(hi)
        m['2constant'] = two_constant

        def create():
            s = self.make_header(self.safe_word(), 'create')
            self.place_cf('docreate')
        m['create'] = create

        def user():
            n = self.popint()
            self.user_word(self.safe_word(), n)
        m['user'] = user

        def nuser():
            self.user_word(self.safe_word(), self.ualloc(4))
        m['nuser'] = m['variable'] = m['lvariable'] = nuser

        def tuser():
            # Token and address user variables.  A null token is
            # represented by the origin, so "0 is foo" stores the origin.
            self.user_word(self.safe_word(), self.ualloc(4), 'tuser')
        m['tuser'] = m['auser'] = tuser

        def wvariable():
            self.user_word(self.safe_word(), self.ualloc(2))
        m['wvariable'] = wvariable

        def two_variable():
            self.user_word(self.safe_word(), self.ualloc(8))
        m['2variable'] = two_variable

        def value():
            name = self.safe_word()
            v = self.pop()
            self.labels[name.lower()] = v
            s = self.make_header(name, 'value')
            self.place_cf('dovalue')
            u = self.ualloc(4)
            self.t_long(u)
            s.user = u
            self.set_user(u, v)
        m['value'] = value

        def defer():
            s = self.make_header(self.safe_word(), 'defer')
            self.place_cf('dodefer')
            u = self.ualloc(4)
            self.t_long(u)
            s.user = u
            self.set_user(u, self.forward('crash'))
        m['defer'] = m['defer-t'] = defer

        def vocabulary():
            name = self.safe_word()
            s = self.make_header(name, 'vocabulary')
            self.place_cf('<vocabulary>')
            u = self.ualloc(4)
            self.t_long(u)
            s.user = u
            self.t_long(self.voc_link)
            self.voc_link = s
            self.cells['voc-link-t'].value = s
            self.t_long(0)
            if name.lower() == 'forth':
                v = Voc(name, self.threads_t)
            else:
                v = Voc(name, [])
            v.user = u
            v.sym = s
            s.voc = v
            self.vocabs.append(v)

            def select(v=v):
                self.context_t = v
            m[name.lower()] = select
        m['vocabulary'] = vocabulary

        def definitions_t():
            if self.context_t is None:
                self.error('definitions-t with no target context')
            self.current_t = self.context_t.words
        m['definitions-t'] = definitions_t

        def file_field():
            # offset size -- offset+size   (filecomm.fth file descriptor)
            name = self.safe_word()
            size = self.popint()
            off = self.popint()
            s = self.make_header(name, 'field')
            self.place_cf('dofield')
            self.t_long(off)
            self.push(off + size)
        m['file-field'] = file_field
        m['struct'] = lambda: self.push(0)

        def tick():
            name = self.safe_word()
            s = self.sym_lookup(name)
            if s is None or not s.defined:
                self.error("%s hasn't been defined yet, so ' won't work"
                           % name)
            self.push(s)
        m["'"] = tick

        def tick_user():
            s = self.sym_lookup(self.safe_word())
            if s is None or s.user is None:
                self.error("'user of a non-user word")
            self.push(s.user)
        m["'user"] = m["'user#"] = tick_user

        def tick_body():
            s = self.sym_lookup(self.safe_word())
            if s is None:
                self.error("'body of an undefined word")
            self.push('%s+4' % s.label)
        m["'body"] = tick_body

        def is_word():
            name = self.safe_word()
            s = self.sym_lookup(name)
            if s is None:
                self.error('%s ?' % name)
            if self.state == 'meta':
                if s.kind in ('value', 'user', 'tuser'):
                    self.compile_name('(is-user)')
                elif s.kind == 'defer':
                    self.compile_name('(is-defer)')
                else:
                    self.error("can't use is with %s" % name)
                self.compile_token(s)
                return
            v = self.pop()
            if s.kind == 'tuser' and v == 0:
                v = 'origin'
            if s.kind in ('value', 'user', 'tuser', 'defer'):
                self.set_user(s.user, v)
            elif s.kind == 'constant':
                s.value = v
                self.out[s.value_idx] = '\t.long %s' % gas_expr(v)
            else:
                self.error("can't use is with %s (%s)" % (name, s.kind))
        m['is'] = t['is'] = is_word

        def immediate():
            self.set_immediate()
        m['immediate'] = immediate

        def resolves():
            name = self.safe_word().lower()
            if self.doestarget is None:
                self.error('resolves with no does> clause')
            self.labels[name] = self.doestarget
        m['resolves'] = resolves

        def rbracket():
            self.state = 'meta'
        m[']'] = rbracket

        # -- transition words (target compilation)
        def lbracket():
            self.state = 'interp'
        t['['] = lbracket

        def semicolon():
            self.compile_name('unnest')
            self.state = 'interp'
            self.hidden_sym = None
            if self.csp is not None and len(self.stack) != self.csp:
                self.error('stack changed during definition of %s'
                           % (self.colon_sym.name if self.colon_sym
                              else '?'))
        t[';'] = semicolon

        def fwd_mark(word):
            self.compile_name(word)
            n = self.newlabel('M')
            self.emit('%s:\t.long %s_t - %s' % (n, n, n))
            return n

        def fwd_resolve(n):
            self.emit('%s_t:' % n)

        def back_mark():
            n = self.newlabel('B')
            self.emit('%s:' % n)
            return n

        def back_resolve(word, n):
            self.compile_name(word)
            self.emit('\t.long %s - .' % n)

        def cs_push(kind, v):
            self.stack.append((kind, v))

        def cs_pop(*kinds):
            v = self.pop()
            if not (isinstance(v, tuple) and v[0] in kinds):
                self.error('control structure mismatch')
            return v[1]

        t['if'] = lambda: cs_push('fwd', fwd_mark('?branch'))
        t['ahead'] = lambda: cs_push('fwd', fwd_mark('branch'))

        def t_else():
            n = fwd_mark('branch')
            old = cs_pop('fwd')
            fwd_resolve(old)
            cs_push('fwd', n)
        t['else'] = t_else
        t['then'] = lambda: fwd_resolve(cs_pop('fwd'))
        t['begin'] = lambda: cs_push('back', back_mark())
        t['until'] = lambda: back_resolve('?branch', cs_pop('back'))
        t['again'] = lambda: back_resolve('branch', cs_pop('back'))

        def t_while():
            n = fwd_mark('?branch')
            b = self.pop()
            cs_push('fwd', n)
            self.push(b)
        t['while'] = t_while

        def t_repeat():
            back_resolve('branch', cs_pop('back'))
            fwd_resolve(cs_pop('fwd'))
        t['repeat'] = t_repeat

        t['do'] = lambda: cs_push('do', fwd_mark('(do)'))
        t['?do'] = lambda: cs_push('do', fwd_mark('(?do)'))
        t['leave'] = lambda: self.compile_name('(leave)')
        t['?leave'] = lambda: self.compile_name('(?leave)')

        def t_loop(word):
            def f():
                n = cs_pop('do')
                self.compile_name(word)
                self.emit('\t.long (%s+4) - .' % n)
                fwd_resolve(n)
            return f
        t['loop'] = t_loop('(loop)')
        t['+loop'] = t_loop('(+loop)')

        def t_case():
            cs_push('case', None)

        def t_of():
            cs_push('of', fwd_mark('(of)'))

        def t_endof():
            n = fwd_mark('(endof)')
            old = cs_pop('of')
            fwd_resolve(old)
            cs_push('endof', n)

        def t_endcase():
            self.compile_name('(endcase)')
            while True:
                v = self.pop()
                if not isinstance(v, tuple):
                    self.error('control structure mismatch in endcase')
                if v[0] == 'case':
                    break
                fwd_resolve(v[1])
        t['case'] = t_case
        t['of'] = t_of
        t['endof'] = t_endof
        t['endcase'] = t_endcase

        t['literal'] = lambda: self.literal(self.pop())
        t['."'] = dotquote
        t['abort"'] = abortquote
        t['"'] = quote
        t['p"'] = pquote

        def s_quote():
            s = self.parse('"')
            self.compile_name('(")')
            self.t_string(s)
        t['s"'] = s_quote

        def c_quote():
            s = self.parse('"')
            self.compile_name('("s)')
            self.t_string(s)
        t['c"'] = c_quote

        def bracket_quotes():
            self.compile_name('("s)')
            self.t_string(self.safe_word())
        t['[""]'] = bracket_quotes

        def bracket_tick():
            self.compile_name("(')")
            self.compile_name(self.safe_word())
        t["[']"] = bracket_tick

        def bracket_compile():
            self.compile_name(self.safe_word())
        t['[compile]'] = bracket_compile
        t['postpone'] = bracket_compile

        def recurse():
            self.compile_token(self.colon_sym)
        t['recurse'] = recurse

        def t_does():
            self.compile_name('(does>)')
            self.t_align()
            lab = self.newlabel('D')
            self.emit('%s:' % lab)
            self.doestarget = lab
            # The does> clause: "call dodoes" padded to 8 bytes; the
            # high-level code of the clause follows.  does-ip? relies on
            # this layout.
            self.emit('\tcall %s' % gas_expr(self.target_ref('dodoes')))
            self.emit('\t.byte 0x90,0x90,0x90')
        t['does>'] = t_does

        def t_semicode():
            self.compile_name('(;code)')
            self.t_align()
            lab = self.newlabel('D')
            self.emit('%s:' % lab)
            self.doestarget = lab
            self.hidden_sym = None
            self.enter_code()
        t[';code'] = t_semicode

    def skip_rest_of_file(self):
        s = self.sources[-1]
        s.lineno = len(s.lines)

    # ------------------------------------------------------------------
    # Output

    def finish(self):
        errors = []
        aliases = []
        for name, s in sorted(self.symbols.items()):
            if not s.defined:
                if name in self.labels:
                    # A forward reference to a label (e.g. an action code
                    # field defined after its first use)
                    aliases.append('\t.set %s, %s'
                                   % (s.label, gas_expr(self.labels[name])))
                    continue
                if name == 'crash':
                    continue
                errors.append(name)
        if errors:
            raise MetaError('undefined target words: ' + ' '.join(errors))
        if self.state != 'interp':
            raise MetaError('input ended in %s state' % self.state)
        if self.stack:
            sys.stderr.write('meta86: warning: host stack not empty: %r\n'
                             % (self.stack,))

        lines = []
        lines.append('# Generated by meta86 -- do not edit.')
        lines.append('\t.code32')
        lines.append('\t.text')
        lines += self.prologue
        lines += aliases
        crash = self.symbols.get('crash')
        if crash is None or not crash.defined:
            lines.append('\t.set f_crash, origin')

        # Vocabulary threads: link fields and thread heads
        for v in self.vocabs:
            prev = 'origin'
            for s in v.words:
                lines.append('\t.set .LK_%s, %s' % (s.label, prev))
                prev = s.label
            self.user_image[v.user] = prev
        orphan = [s for s in self.threads_t
                  if not any(v.words is self.threads_t for v in self.vocabs)]
        prev = 'origin'
        for s in orphan:
            lines.append('\t.set .LK_%s, %s' % (s.label, prev))
            prev = s.label

        lines += self.out
        lines.append('\t.p2align 2,0')
        lines.append('\t.globl dict_end')
        lines.append('dict_end:')
        lines.append('\t.globl init_user_area')
        lines.append('init_user_area:')
        for off in range(0, self.user_size, 4):
            v = self.user_image.get(off, 0)
            lines.append('\t.long %s' % gas_expr(v))
        for off in self.user_image:
            if off % 4:
                raise MetaError('misaligned user-area initializer')
        lines.append('\t.globl init_user_area_end')
        lines.append('init_user_area_end:')
        lines.append('\t.set user_size, %d' % self.user_size)
        lines.append('\t.set user_used, %d' % self.cells['#user-t'].value)
        return '\n'.join(lines) + '\n'


def main(argv):
    defines = []
    bp = None
    outname = None
    deps = None
    args = argv[1:]
    files = []
    while args:
        a = args.pop(0)
        if a == '-D':
            defines.append(args.pop(0))
        elif a.startswith('-D'):
            defines.append(a[2:])
        elif a == '-I':
            bp = args.pop(0)
        elif a == '-o':
            outname = args.pop(0)
        elif a == '-M':
            deps = args.pop(0)
        else:
            files.append(a)
    if not files or not outname:
        sys.stderr.write(__doc__)
        return 2
    if bp is None:
        bp = os.environ.get('BP') or os.path.abspath(
            os.path.join(os.path.dirname(__file__), '..', '..', '..'))
    meta = Meta(bp, defines)
    try:
        for f in reversed(files):
            meta.include(f)
        meta.run()
        text = meta.finish()
    except MetaError as e:
        sys.stderr.write('meta86: %s\n' % e)
        return 1
    with open(outname, 'w') as f:
        f.write(text)
    if deps:
        with open(deps, 'w') as f:
            f.write('%s: %s\n' % (outname, ' '.join(meta.files_loaded)))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
