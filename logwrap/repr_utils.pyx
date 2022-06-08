#    Copyright 2016 - 2022 Alexey Stepanov aka penguinolog

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

"""repr_utils module.

This is no reason to import this submodule directly, all required methods is
available from the main module.
"""

# Standard Library
import dataclasses
import inspect
import types
import typing
from collections.abc import Iterable

__all__ = ("PrettyFormat", "PrettyRepr", "PrettyStr", "pretty_repr", "pretty_str")

_SIMPLE_MAGIC_ATTRIBUTES = ("__repr__", "__str__")


@typing.runtime_checkable
class _AttributeHolderProto(typing.Protocol):
    __slots__ = ()

    def _get_kwargs(self) -> list[tuple[str, typing.Any]]:
        """Protocol stub."""

    def _get_args(self) -> list[str]:
        """Protocol stub."""


@typing.runtime_checkable
class _NamedTupleProto(typing.Protocol):
    __slots__ = ()

    def _asdict(self) -> dict[str, typing.Any]:
        """Protocol stub."""

    def __getnewargs__(self) -> tuple[typing.Any, ...]:
        """Protocol stub."""

    def _replace(self, **kwds: dict[str, typing.Any]) -> _NamedTupleProto:
        """Protocol stub."""

    @classmethod
    def _make(cls, iterable: Iterable[typing.Any]) -> _NamedTupleProto:
        """Protocol stub."""


@typing.runtime_checkable
class _DataClassProto(typing.Protocol):
    __slots__ = ()

    __dataclass_params__: dataclasses._DataclassParams  # type: ignore[name-defined]
    __dataclass_fields__: dict[str, dataclasses.Field[typing.Any]] = {}

cdef:
    bint _known_callable(item: typing.Any):
        """Check for possibility to parse callable.

        :param item:  item to check for repr() way
        :type item: typing.Any
        :return: item is callable and should be processed not using repr
        :rtype: bool
        """
        return isinstance(item, (types.FunctionType, types.MethodType))


    bint _simple(item: typing.Any):
        """Check for nested iterations: True, if not.

        :param item: item to check for repr() way
        :type item: typing.Any
        :return: use repr() iver item by default
        :rtype: bool
        """
        return not any(
            (
                isinstance(item, data_type)
                and all(
                    getattr(type(item), attribute) is getattr(data_type, attribute)
                    for attribute in _SIMPLE_MAGIC_ATTRIBUTES
                )
            )
            for data_type in (list, set, tuple, dict, frozenset)
        )


    class ReprParameter:
        """Parameter wrapper wor repr and str operations over signature."""

        def __cinit__(self, parameter: inspect.Parameter, value: typing.Any = inspect.Parameter.empty) -> None:
            """Parameter-like object store BOUND with value parameter.

            :param parameter: parameter from signature
            :type parameter: inspect.Parameter
            :param value: parameter real value
            :type value: typing.Any
            :raises ValueError: No default value and no value
            """
            # Fill enum
            self.POSITIONAL_ONLY = inspect.Parameter.POSITIONAL_ONLY
            self.POSITIONAL_OR_KEYWORD = inspect.Parameter.POSITIONAL_OR_KEYWORD
            self.VAR_POSITIONAL = inspect.Parameter.VAR_POSITIONAL
            self.KEYWORD_ONLY = inspect.Parameter.KEYWORD_ONLY
            self.VAR_KEYWORD = inspect.Parameter.VAR_KEYWORD
            self.empty = inspect.Parameter.empty

            # Real data
            self.parameter = parameter
            self.kind = self.parameter.kind

            if parameter.kind == inspect.Parameter.VAR_POSITIONAL:
                self.name = "*" + self.parameter.name
            elif self.kind == inspect.Parameter.VAR_KEYWORD:
                self.name = "**" + self.parameter.name
            else:
                self.name = self.parameter.name

            self.annotation = self.parameter.annotation
            self.value = value if value is not parameter.empty else parameter.default

        # noinspection PyTypeChecker
        def __hash__(self) -> typing.NoReturn:
            """Block hashing.

            :raises TypeError: Not hashable.
            """
            cdef str msg = f"not hashable type: '{self.__class__.__name__}'"
            raise TypeError(msg)

        def __repr__(self) -> str:
            """Debug purposes.

            :return: parameter repr for debug purposes
            :rtype: str
            """
            return f'<{self.__class__.__name__} "{self}">'


    list _prepare_repr(func: typing.Union[types.FunctionType, types.MethodType]):
        """Get arguments lists with defaults.

        :param func: Callable object to process
        :type func: typing.Union[types.FunctionType, types.MethodType]
        :return: repr of callable parameter from signature
        :rtype: typing.List[ReprParameter]"""
        cdef:
            bint ismethod = isinstance(func, types.MethodType)
            bint self_processed = False
            list result = []

        if not ismethod:
            real_func = func
        else:
            real_func = func.__func__

        for param in inspect.signature(real_func).parameters.values():
            if not self_processed and ismethod and func.__self__ is not None:
                result.append(ReprParameter(param, value=func.__self__))
                self_processed = True
            else:
                result.append(ReprParameter(param))

        return result


cdef class PrettyFormat:
    """Pretty Formatter.

    Designed for usage as __repr__ and __str__ replacement on complex objects
    """

    def __cinit__(self, unsigned long max_indent=20, unsigned long indent_step=4):
        """Pretty Formatter.

        :param max_indent: maximal indent before classic repr() call
        :type max_indent: int
        :param indent_step: step for the next indentation level
        :type indent_step: int
        """
        self.max_indent = max_indent
        self.indent_step = indent_step

    cpdef unsigned long next_indent(self, unsigned long indent, unsigned long multiplier=1):
        """Next indentation value.

        :param indent: current indentation value
        :type indent: int
        :param multiplier: step multiplier
        :type multiplier: int
        :return: next indentation value
        :rtype: int
        """
        return indent + multiplier * self.indent_step

    cdef:
        str _repr_callable(
            self,
            src: typing.Union[types.FunctionType, types.MethodType],
            unsigned long indent=0
        ):
            """Repr callable object (function or method).

            :param src: Callable to process
            :type src: typing.Union[types.FunctionType, types.MethodType]
            :param indent: start indentation
            :type indent: int
            :return: Repr of function or method with signature.
            :rtype: str
            """
            cdef:
                str param_str = ""
                unsigned long next_indent = self.next_indent(indent)
                str prefix="\n" + " " * next_indent
                str annotation
                ReprParameter param

            for param in _prepare_repr(src):
                param_str += f"{prefix}{param.name}"
                annotation_exist = param.annotation is not param.empty
                if annotation_exist:
                    param_str += f": {getattr(param.annotation, '__name__', param.annotation)!s}"
                if param.value is not param.empty:
                    if annotation_exist:
                        param_str += " = "
                    else:
                        param_str += "="
                    cdef:
                        value = self.process_element(src=param.value, indent=next_indent, no_indent_start=True)
                    param_str += value
                param_str += ","

            if param_str:
                param_str += "\n" + " " * indent

            sig = inspect.signature(src)
            if sig.return_annotation is inspect.Parameter.empty:
                annotation = ""
            elif sig.return_annotation is type(None):  # noqa: E721
                # Python 3.10 special case
                annotation = " -> None"
            else:
                annotation = f" -> {getattr(sig.return_annotation, '__name__', sig.return_annotation)!s}"

            return (
                f"{'':<{indent}}"
                f"<{src.__class__.__name__} {src.__module__}.{src.__name__} with interface ({param_str}){annotation}>"
            )

        str _repr_attribute_holder(
            self,
            src: _AttributeHolderProto,
            unsigned long indent=0,
            bint no_indent_start=False
        ):
            """Repr attribute holder object (like argparse objects).

            :param src: attribute holder object to process
            :type src: _AttributeHolderProto
            :param indent: start indentation
            :type indent: int
            :return: Repr of attribute holder object.
            :rtype: str
            """
            param_repr: list[str] = []
            star_args: dict[str, typing.Any] = {}

            cdef:
                unsigned long next_indent = self.next_indent(indent)
                str prefix = "\n" + " " * next_indent

            for arg in src._get_args():  # pylint: disable=protected-access
                cdef repr_val = self.process_element(arg, indent=next_indent)
                param_repr.append(f"{prefix}{repr_val},")

            for name, value in src._get_kwargs():  # pylint: disable=protected-access
                if name.isidentifier():
                    cdef repr_val = self.process_element(value, indent=next_indent, no_indent_start=True)
                    param_repr.append(f"{prefix}{name}={repr_val},")
                else:
                    star_args[name] = value

            if star_args:
                cdef repr_val = self.process_element(star_args, indent=next_indent, no_indent_start=True)
                param_repr.append(f"{prefix}**{repr_val},")

            if param_repr:
                param_repr.append("\n")
                param_repr.append(" " * indent)

            param_str = "".join(param_repr)
            return f"{'':<{indent if not no_indent_start else 0}}{src.__module__}.{src.__class__.__name__}({param_str})"

        str _repr_named_tuple(
            self,
            src: _NamedTupleProto,
            unsigned long indent=0,
            bint no_indent_start=False
        ):
            """Repr named tuple.

            :param src: named tuple object to process
            :type src: _NamedTupleProto
            :param indent: start indentation
            :type indent: int
            :return: Repr of named tuple object.
            :rtype: str
            """
            param_repr: list[str] = []

            try:
                args_annotations: dict[str, typing.Any] = typing.get_type_hints(src)
            except BaseException:  # NOSONAR
                args_annotations = {}

            cdef :
                unsigned long next_indent = self.next_indent(indent)
                str prefix = "\n" + " " * next_indent

            for arg_name, value in src._asdict().items():
                cdef repr_val = self.process_element(value, indent=next_indent, no_indent_start=True)
                param_repr.append(f"{prefix}{arg_name}={repr_val},")
                if arg_name in args_annotations and not isinstance(
                    getattr(args_annotations, arg_name, None), typing.ForwardRef
                ):
                    annotation = getattr(args_annotations[arg_name], '__name__', args_annotations[arg_name])
                    param_repr.append(f"#  type: {annotation!s}")

            if param_repr:
                param_repr.append("\n")
                param_repr.append(" " * indent)

            param_str = "".join(param_repr)
            return f"{'':<{indent if not no_indent_start else 0}}{src.__module__}.{src.__class__.__name__}({param_str})"

        str _repr_dataclass(
            self,
            src: _DataClassProto,
            unsigned long indent=0,
            bint no_indent_start=False
        ):
            """Repr dataclass.

            :param src: dataclass object to process
            :type src: _DataClassProto
            :param indent: start indentation
            :type indent: int
            :return: Repr of dataclass.
            :rtype: str
            """
            param_repr: list[str] = []

            cdef:
                unsigned long next_indent = self.next_indent(indent)
                str prefix = "\n" + " " * next_indent

            for arg_name, field in src.__dataclass_fields__.items():
                if not field.repr:
                    continue
                cdef repr_val = self.process_element(getattr(src, arg_name), indent=next_indent, no_indent_start=True)

                comment: list[str] = []

                if field.type:
                    if isinstance(field.type, str):
                        comment.append(f"type: {field.type}")
                    else:
                        comment.append(f"type: {field.type.__name__}")
                if getattr(field, "kw_only", False):  # python 3.10+
                    comment.append("kw_only")

                if comment:
                    comment_str = "  # " + "  # ".join(comment)
                else:
                    comment_str = ""

                param_repr.append(f"{prefix}{arg_name}={repr_val},{comment_str}")

            if param_repr:
                param_repr.append("\n")
                param_repr.append(" " * indent)

            param_str = "".join(param_repr)
            return f"{'':<{indent if not no_indent_start else 0}}{src.__module__}.{src.__class__.__name__}({param_str})"

        str _repr_simple(
            self,
            src: typing.Any,
            unsigned long indent=0,
            bint no_indent_start=False
        ):
            """Repr object without iteration.

            :param src: Source object
            :type src: typing.Any
            :param indent: start indentation
            :type indent: int
            :param no_indent_start: ignore indent
            :type no_indent_start: bool
            :return: simple repr() over object
            :rtype: str
            """
            raise NotImplementedError()

        str _repr_iterable_item(
            self,
            str obj_type,
            str prefix,
            unsigned long indent,
            bint no_indent_start,
            str result,
            str suffix
        ):
            """Repr iterable item.

            :param obj_type: Object type
            :type obj_type: str
            :param prefix: prefix
            :type prefix: str
            :param indent: start indentation
            :type indent: int
            :param no_indent_start: ignore indent
            :type no_indent_start: bool
            :param result: result of pre-formatting
            :type result: str
            :param suffix: suffix
            :type suffix: str
            :return: formatted repr of "result" with prefix and suffix to explain type.
            :rtype: str
            """
            raise NotImplementedError()

        str _repr_dict_items(
            self,
            object src: typing.Dict[typing.Any, typing.Any],
            unsigned long indent=0
        ):
            """Repr dict items.

            :param src: object to process
            :type src: typing.Dict
            :param indent: start indentation
            :type indent: int
            :return: repr of key/value pairs from dict
            :rtype: typing.Iterator[str]
            """
            raise NotImplementedError()

        str _repr_iterable_items(
            self,
            src: typing.Iterable[typing.Any],
            unsigned long indent=0
        ):
            """Repr iterable items (not designed for dicts).

            :param src: object to process
            :type src: typing.Iterable
            :param indent: start indentation
            :type indent: int
            :return: repr of elements in iterable item
            :rtype: str
            """
            cdef:
                unsigned long next_indent=self.next_indent(indent)
                list buf = []
            for elem in src:
                buf.append("\n")
                buf.append(self.process_element(src=elem, indent=next_indent))
                buf.append(",")
            return "".join(buf)

    cpdef str process_element(
        self,
        src: typing.Any,
        unsigned long indent=0,
        bint no_indent_start=False
    ):
        """Make human readable representation of object.

        :param src: object to process
        :type src: typing.Any
        :param indent: start indentation
        :type indent: int
        :param no_indent_start: do not indent open bracket and simple parameters
        :type no_indent_start: bool
        :return: formatted string
        :rtype: str
        """
        cdef:
            str prefix
            str suffix
            str result
            str new_line

        if hasattr(src, self._magic_method_name):
            result = getattr(src, self._magic_method_name)(self, indent=indent, no_indent_start=no_indent_start)
            return result

        if _known_callable(src):
            return self._repr_callable(src=src, indent=indent)

        if isinstance(src, _AttributeHolderProto):
            return self._repr_attribute_holder(src=src, indent=indent, no_indent_start=no_indent_start)

        if isinstance(src, tuple) and isinstance(src, _NamedTupleProto):
            return self._repr_named_tuple(src=src, indent=indent, no_indent_start=no_indent_start)

        if isinstance(src, _DataClassProto) and not isinstance(src, type) and src.__dataclass_params__.repr:
            return self._repr_dataclass(src=src, indent=indent, no_indent_start=no_indent_start)

        if _simple(src) or indent >= self.max_indent or not src:
            return self._repr_simple(src=src, indent=indent, no_indent_start=no_indent_start)

        if isinstance(src, dict):
            prefix, suffix = "{", "}"
            result = self._repr_dict_items(src=src, indent=indent)
        else:
            if isinstance(src, list):
                prefix, suffix = "[", "]"
            elif isinstance(src, tuple):
                prefix, suffix = "(", ")"
            else:
                prefix, suffix = "{", "}"
            result = self._repr_iterable_items(src=src, indent=indent)

        if type(src) in (list, tuple, set, dict):
            return f"{'':<{indent if not no_indent_start else 0}}{prefix}{result}\n{'':<{indent}}{suffix}"

        return self._repr_iterable_item(
            obj_type=src.__class__.__name__,
            prefix=prefix,
            indent=indent,
            no_indent_start=no_indent_start,
            result=result,
            suffix=suffix,
        )

    def __call__(
        self,
        src: typing.Any,
        unsigned long indent=0,
        bint no_indent_start=False
    ) -> str:
        """Make human-readable representation of object. The main entry point.

        :param src: object to process
        :type src: typing.Any
        :param indent: start indentation
        :type indent: int
        :param no_indent_start: do not indent open bracket and simple parameters
        :type no_indent_start: bool
        :return: formatted string
        :rtype: str
        """
        result = self.process_element(src, indent=indent, no_indent_start=no_indent_start)
        return result


cdef class PrettyRepr(PrettyFormat):
    """Pretty repr.

    Designed for usage as __repr__ replacement on complex objects
    """

    __slots__ = ()

    def __cinit__(self, unsigned long max_indent=20, unsigned long indent_step=4):
        self._magic_method_name = "__pretty_repr__"

    cdef:
        str _repr_simple(
            self,
            src: typing.Any,
            unsigned long indent=0,
            bint no_indent_start=False
        ):
            """Repr object without iteration.

            :param src: Source object
            :type src: typing.Any
            :param indent: start indentation
            :type indent: int
            :param no_indent_start: ignore indent
            :type no_indent_start: bool
            :return: simple repr() over object, except strings (add prefix) and set (uniform py2/py3)
            :rtype: str
            """
            return f"{'':<{0 if no_indent_start else indent}}{src!r}"

        str _repr_iterable_item(
            self,
            str obj_type,
            str prefix,
            unsigned long indent,
            bint no_indent_start,
            str result,
            str suffix
        ):
            """Repr iterable item.

            :param obj_type: Object type
            :type obj_type: str
            :param prefix: prefix
            :type prefix: str
            :param indent: start indentation
            :type indent: int
            :param no_indent_start: ignore indent
            :type no_indent_start: bool
            :param result: result of pre-formatting
            :type result: str
            :param suffix: suffix
            :type suffix: str
            :return: formatted repr of "result" with prefix and suffix to explain type.
            :rtype: str
            """
            return f"{'':<{indent if not no_indent_start else 0}}{obj_type}({prefix}{result}\n{'':<{indent}}{suffix})"

        str _repr_dict_items(
            self,
            object src: typing.Dict[typing.Any, typing.Any],
            unsigned long indent=0
        ):
            """Repr dict items.

            :param src: object to process
            :type src: typing.Dict
            :param indent: start indentation
            :type indent: int
            :return: repr of key/value pairs from dict
            :rtype: str
            """
            cdef:
                unsigned long max_len = max((len(repr(key)) for key in src)) if src else 0
                unsigned long next_indent=self.next_indent(indent)
                str prefix="\n" + " " * next_indent
                list buf = []

            for key, val in src.items():
                buf.append(prefix)
                buf.append(f"{key!r:{max_len}}: ")
                buf.append(self.process_element(val, indent=next_indent, no_indent_start=True))
                buf.append(",")
            return "".join(buf)


cdef class PrettyStr(PrettyFormat):
    """Pretty str.

    Designed for usage as __str__ replacement on complex objects
    """

    def __cinit__(self, unsigned long max_indent=20, unsigned long indent_step=4):
        self._magic_method_name = "__pretty_str__"

    cdef:
        str _strings_str(
            self,
            unsigned long indent,
            val: typing.Union[bytes, str]
        ):
            """Custom repr for strings and binary strings.

            :param indent: result indent
            :type indent: int
            :param val: value for repr
            :type val: typing.Union[bytes, str]
            :return: indented string as `str`
            :rtype: str
            """
            cdef str string
            if isinstance(val, bytes):
                string = val.decode(encoding="utf-8", errors="backslashreplace")
            else:
                string = val
            return f"{'':<{indent}}{string}"

        str _repr_simple(
            self,
            src: typing.Any,
            unsigned long indent=0,
            bint no_indent_start=False
        ):
            """Repr object without iteration.

            :param src: Source object
            :type src: typing.Any
            :param indent: start indentation
            :type indent: int
            :param no_indent_start: ignore indent
            :type no_indent_start: bool
            :return: simple repr() over object, except strings (decode) and set (uniform py2/py3)
            :rtype: str
            """
            cdef unsigned long real_indent = 0 if no_indent_start else indent
            if isinstance(src, (bytes, str)):
                return self._strings_str(indent=real_indent, val=src)
            return f"{'':<{real_indent}}{src!s}"

        str _repr_iterable_item(
            self,
            str obj_type,
            str prefix,
            unsigned long indent,
            bint no_indent_start,
            str result,
            str suffix
        ):
            """Repr iterable item.

            :param obj_type: Object type
            :type obj_type: str
            :param prefix: prefix
            :type prefix: str
            :param indent: start indentation
            :type indent: int
            :param no_indent_start: ignore indent
            :type no_indent_start: bool
            :param result: result of pre-formatting
            :type result: str
            :param suffix: suffix
            :type suffix: str
            :return: formatted repr of "result" with prefix and suffix to explain type.
            :rtype: str
            """
            return f"{'':<{indent if not no_indent_start else 0}}{prefix}{result}\n{'':<{indent}}{suffix}"

        str _repr_dict_items(
            self,
            object src: typing.Dict[typing.Any, typing.Any],
            unsigned long indent=0
        ):
            """Repr dict items.

            :param src: object to process
            :type src: typing.Dict
            :param indent: start indentation
            :type indent: int
            :return: repr of key/value pairs from dict
            :rtype: str
            """
            cdef:
                unsigned long max_len = max((len(str(key)) for key in src)) if src else 0
                unsigned long next_indent=self.next_indent(indent)
                str prefix="\n" + " " * next_indent
                list buf = []

            for key, val in src.items():
                buf.append(prefix)
                buf.append(f"{key!s:{max_len}}: ")
                buf.append(self.process_element(val, indent=next_indent, no_indent_start=True))
                buf.append(",")
            return "".join(buf)


cpdef str pretty_repr(
    src: typing.Any,
    unsigned long indent=0,
    bint no_indent_start=False,
    unsigned long max_indent=20,
    unsigned long indent_step=4
):
    """Make human readable repr of object.

    :param src: object to process
    :type src: typing.Any
    :param indent: start indentation, all next levels is +indent_step
    :type indent: int
    :param no_indent_start: do not indent open bracket and simple parameters
    :type no_indent_start: bool
    :param max_indent: maximal indent before classic repr() call
    :type max_indent: int
    :param indent_step: step for the next indentation level
    :type indent_step: int
    :return: formatted string
    :rtype: str
    """
    return PrettyRepr(max_indent=max_indent, indent_step=indent_step)(
        src=src,
        indent=indent,
        no_indent_start=no_indent_start,
    )


cpdef str pretty_str(
    src: typing.Any,
    unsigned long indent=0,
    bint no_indent_start=False,
    unsigned long max_indent=20,
    unsigned long indent_step=4
):
    """Make human readable str of object.

    :param src: object to process
    :type src: typing.Any
    :param indent: start indentation, all next levels is +indent_step
    :type indent: int
    :param no_indent_start: do not indent open bracket and simple parameters
    :type no_indent_start: bool
    :param max_indent: maximal indent before classic repr() call
    :type max_indent: int
    :param indent_step: step for the next indentation level
    :type indent_step: int
    :return: formatted string
    """
    return PrettyStr(max_indent=max_indent, indent_step=indent_step)(
        src=src,
        indent=indent,
        no_indent_start=no_indent_start,
    )
