#    Copyright 2016 Alexey Stepanov aka penguinolog

#    Copyright 2016 Mirantis, Inc.

#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.

# pylint: disable=missing-docstring

"""_repr_utils (internal helpers) specific tests."""

# Standard Library
import typing
import unittest

# LogWrap Implementation
import logwrap


# noinspection PyUnusedLocal,PyMissingOrEmptyDocstring
class TestPrettyRepr(unittest.TestCase):
    def test_001_simple(self):
        self.assertEqual(
            logwrap.pretty_repr(True), repr(True)
        )

    def test_002_text(self):
        txt = 'Unicode text'
        b_txt = b'bytes text\x01'
        self.assertEqual(
            repr(txt), logwrap.pretty_repr(txt)
        )
        self.assertEqual(
            repr(b_txt), logwrap.pretty_repr(b_txt)
        )

    def test_003_iterable(self):
        self.assertEqual(
            '[{nl:<5}1,{nl:<5}2,{nl:<5}3,\n]'.format(nl='\n'),
            logwrap.pretty_repr([1, 2, 3]),
        )
        self.assertEqual(
            '({nl:<5}1,{nl:<5}2,{nl:<5}3,\n)'.format(nl='\n'),
            logwrap.pretty_repr((1, 2, 3)),
        )
        res = logwrap.pretty_repr({1, 2, 3})
        self.assertTrue(
            res.startswith('{') and res.endswith('\n}')
        )
        res = logwrap.pretty_repr(frozenset({1, 2, 3}))
        self.assertTrue(
            res.startswith('frozenset({') and res.endswith('\n})')
        )

    def test_004_dict(self):
        self.assertEqual(
            '{\n'
            '    1 : 1,\n'
            '    2 : 2,\n'
            '    33: 33,\n'
            '}',
            logwrap.pretty_repr({1: 1, 2: 2, 33: 33}),
        )

    def test_005_nested_obj(self):
        test_obj = [
            {1: 2},
            {3: {4}},
            [5, 6, 7],
            (8, 9, 10),
            {},
            [],
            (),
            set(),
        ]
        exp_repr = (
            '[\n'
            '    {\n'
            '        1: 2,\n'
            '    },\n'
            '    {\n'
            '        3: \n'
            '            {\n'
            '                4,\n'
            '            },\n'
            '    },\n'
            '    [\n'
            '        5,\n'
            '        6,\n'
            '        7,\n'
            '    ],\n'
            '    (\n'
            '        8,\n'
            '        9,\n'
            '        10,\n'
            '    ),\n'
            '    {},\n'
            '    [],\n'
            '    (),\n'
            '    set(),\n'
            ']'
        )
        self.assertEqual(exp_repr, logwrap.pretty_repr(test_obj))

    def test_006_callable(self):
        fmt = "{spc:<{indent}}<{obj!r} with interface ({args})>".format

        def empty_func():
            pass

        def full_func(arg, darg=1, *positional, **named):
            pass

        # noinspection PyMissingOrEmptyDocstring
        class TstClass(object):
            def tst_method(self, arg, darg=1, *positional, **named):
                pass

            @classmethod
            def tst_classmethod(cls, arg, darg=1, *positional, **named):
                pass

        tst_instance = TstClass()

        self.assertEqual(
            logwrap.pretty_repr(empty_func),
            fmt(spc='', indent=0, obj=empty_func, args='')
        )

        self.assertEqual(
            logwrap.pretty_repr(full_func),
            fmt(
                spc='',
                indent=0,
                obj=full_func,
                args='\n'
                '    arg,\n'
                '    darg=1,\n'
                '    *positional,\n'
                '    **named,\n'
            )
        )

        obj = TstClass.tst_method

        self.assertEqual(
            logwrap.pretty_repr(obj),
            fmt(
                spc='',
                indent=0,
                obj=obj,
                args='\n'
                     '    self,\n'
                     '    arg,\n'
                     '    darg=1,\n'
                     '    *positional,\n'
                     '    **named,\n'
            )
        )

        obj = TstClass.tst_classmethod

        self.assertEqual(
            logwrap.pretty_repr(obj),
            fmt(
                spc='',
                indent=0,
                obj=obj,
                args='\n'
                     '    cls={cls!r},\n'
                     '    arg,\n'
                     '    darg=1,\n'
                     '    *positional,\n'
                     '    **named,\n'.format(cls=TstClass)
            )
        )

        obj = tst_instance.tst_method

        self.assertEqual(
            logwrap.pretty_repr(obj),
            fmt(
                spc='',
                indent=0,
                obj=obj,
                args='\n'
                     '    self={self!r},\n'
                     '    arg,\n'
                     '    darg=1,\n'
                     '    *positional,\n'
                     '    **named,\n'.format(self=tst_instance)
            )
        )

        obj = tst_instance.tst_classmethod

        self.assertEqual(
            logwrap.pretty_repr(obj),
            fmt(
                spc='',
                indent=0,
                obj=obj,
                args='\n'
                     '    cls={cls!r},\n'
                     '    arg,\n'
                     '    darg=1,\n'
                     '    *positional,\n'
                     '    **named,\n'.format(cls=TstClass)
            )
        )

    def test_007_indent(self):
        obj = [[[[[[[[[[123]]]]]]]]]]
        self.assertEqual(
            "[\n"
            "    [\n"
            "        [\n"
            "            [\n"
            "                [\n"
            "                    [\n"
            "                        [\n"
            "                            [\n"
            "                                [\n"
            "                                    [\n"
            "                                        123,\n"
            "                                    ],\n"
            "                                ],\n"
            "                            ],\n"
            "                        ],\n"
            "                    ],\n"
            "                ],\n"
            "            ],\n"
            "        ],\n"
            "    ],\n"
            "]",
            logwrap.pretty_repr(obj, max_indent=40),
        )
        self.assertEqual(
            "[\n"
            "    [\n"
            "        [\n"
            "            [[[[[[[123]]]]]]],\n"
            "        ],\n"
            "    ],\n"
            "]",
            logwrap.pretty_repr(obj, max_indent=10),
        )

    def test_008_magic_override(self):
        # noinspection PyMissingOrEmptyDocstring
        class Tst(object):
            def __repr__(self):
                return 'Test'

            def __pretty_repr__(
                self,
                parser,
                indent,
                no_indent_start
            ):
                return parser.process_element(
                    f"<Test Class at 0x{id(self.__class__):X}>",
                    indent=indent,
                    no_indent_start=no_indent_start
                )

        result = logwrap.pretty_repr(Tst())
        self.assertNotEqual(
            result,
            'Test'
        )
        self.assertEqual(
            result,
            f"'<Test Class at 0x{id(Tst):X}>'"
        )


# noinspection PyUnusedLocal,PyMissingOrEmptyDocstring
class TestAnnotated(unittest.TestCase):
    def test_001_annotation_args(self):
        fmt = "{spc:<{indent}}<{obj!r} with interface ({args}){annotation}>".format

        def func(a: typing.Optional[int] = None):
            pass

        self.assertEqual(
            logwrap.pretty_repr(func),
            fmt(
                spc='',
                indent=0,
                obj=func,
                args="\n    a: typing.Union[int, NoneType]=None,\n",
                annotation=""
            )
        )

        self.assertEqual(
            logwrap.pretty_str(func),
            fmt(
                spc='',
                indent=0,
                obj=func,
                args="\n    a: typing.Union[int, NoneType]=None,\n",
                annotation=""
            )
        )

    def test_002_annotation_return(self):
        fmt = "{spc:<{indent}}<{obj!r} with interface ({args}){annotation}>".format

        def func() -> None:
            pass

        self.assertEqual(
            logwrap.pretty_repr(func),
            fmt(
                spc='',
                indent=0,
                obj=func,
                args='',
                annotation=' -> None'
            )
        )

        self.assertEqual(
            logwrap.pretty_str(func),
            fmt(
                spc='',
                indent=0,
                obj=func,
                args='',
                annotation=' -> None'
            )
        )

    def test_003_complex(self):
        fmt = "{spc:<{indent}}<{obj!r} with interface ({args}){annotation}>".format

        def func(a: typing.Optional[int] = None) -> None:
            pass

        self.assertEqual(
            logwrap.pretty_repr(func),
            fmt(
                spc='',
                indent=0,
                obj=func,
                args="\n    a: typing.Union[int, NoneType]=None,\n",
                annotation=" -> None"
            )
        )

        self.assertEqual(
            logwrap.pretty_str(func),
            fmt(
                spc='',
                indent=0,
                obj=func,
                args="\n    a: typing.Union[int, NoneType]=None,\n",
                annotation=" -> None"
            )
        )
