---
title: "The Case for Dependency Injection"
date: 2026-11-01
---

## Demystifing Dependency Injection

In software, we're typically wiring together {term}`services<service>` and {term}`service consumers<consumer>`. These units of abstraction underpin software development principles of writing maintainable, extensible code.

:::{glossary}
Service
: A unit of code that implements an API that other units of code may consume, e.g a Python module or class

Consumer
: A unit of code that uses an API provided by another {term}`service`.
:::

For example, imagine that you're writing an analysis script that uses a plotting tool. You could start with a simple function:

```python
from matplotlib import pyplot as plt

def plot_something():
    plt.figure()
    plt.plot(..., ...)
    plt.save("figure.png")

plot_something()
```

Down the road, you might want to support a different plotting tool like `plotly`. What is the cleanest way to do this? The obvious approach would be to introduce a `IPlotter` interface, and pass in the plotter as an argument to the plotting function:

```python
from typing import Protocol
from matplotlib import pyplot as mpl_plotter

class IPlotter(Protocol):
    def figure(self, ...):
        ...

    def plot(self, ...):
        ...

    def save(self,  ...):
        ...

class PlotlyPlotter(IPlotter):
    def figure(self, ...):
        ...

    def plot(self, ...):
        ...

    def save(self,  ...):
        ...

def plot_something(plotter: IPlotter):
    plotter.figure()
    plotter.plot(..., ...)
    plotter.save("figure.png")

def main():
    plotly_plotter = PlotlyPlotter()
    plot_something(plotly_plotter)

    plot_something(mpl_plotter)

if __name__ == "__main__":
    main()
```

![](https://raw.githubusercontent.com/agoose77/packaging-pyopp-2025/refs/heads/main/media/dependency-injection.webp)

Congratulations! By abstracting the plotting feature into a {term}`service`, and hoisting the provisioning of that service into a different context, you've just injected a dependency!

## Handling Nested Dependencies

Let's imagine that our `mpl_plotter` service doesn't support JPEG XL export, and we want to facilitate this using some image conversion tools:

```{code} python
:linenos:
:emphasize-lines: 13-21
from image_converter import SpecialImageConverter
from matplotlib import pyplot as plt


class MPLPlotter(IPlotter):

    def figure(self, ...):
        ...

    def plot(self, ...):
        ...

    def save(filename: str):
        if filename.endswith(".jxl"):
            # Save to wepb
            webp_path = "/tmp/image.webp"
            plt.save(webp_path)

            # Perform the conversion
            converter = SpecialImageConverter()
            return converter.webp_to_jxl(webp_path)
```

If we want to support _arbitrary_ converters, we need to consruct the `ImageConverter()` ourselves, and pass it in as an argument:

```{code} python
:linenos:
:emphasize-lines: 9-10
from image_converter import SpecialImageConverter
from matplotlib import pyplot as plt


class MPLPlotter(IPlotter):
    ...

def main():
    converter = SpecialImageConverter()
    plotter = MPLPlotter(converter)

    plot_something(plotter)

if __name__ == "__main__":
    main()
```

At this point, a pattern is starting to emerge. Any time we need to pass something "down" to a consumer, we have to prop-drill i.e. pass it through all the calling functions and classes:

```{mermaid}
graph LR;

main --> plot_something
```

For example, let's do some analysis before plotting:

```{code} python
:linenos:
:emphasize-lines: 7-12,20-21
def plot_something(plotter: Plotter):
    plotter.figure()
    plotter.plot(..., ...)
    plotter.save("figure.png")


def analyse_first(plotter):
    plot_something(plotter)


def analyse_second(plotter):
    plot_something(plotter)



def main():
    converter = SpecialImageConverter()
    plotter = MPLPlotter(converter)

    analyse_first(plotter)
    analyse_second(plotter)

if __name__ == "__main__":
    main()
```

We now have a deeper hierarchy, where `plotter` is only taken by `analyse_first` in order to pass it to `plot_something`:

```{mermaid}
graph LR;
main --> analyse_first --> plot_something
main --> analyse_second --> plot_something

```

This quickly becomes complicated, and imposes constraints on program design — adding a new service in `plot_something` requires modifying both `plot_something`, and the `analyse_` functions.

## Using a Dependency Injector

The easiest way to handle this complexity with imperative programs is to keep the call depth shallow, and construct services at the top level. But, this constraint is difficult to enforce and painful to design within.

A dependency injector can help to eliminate this complexity by separating dependency wiring from call stacks. Imagine we have a dependency injector that understands function signatures, and wires up each needed {term}`service` to its dependent {term}`consumers<consumer>`. In Python, this might look something like:

```python
@injector.service
def analyse_first(plotter: Plotter):
    plot_something(plotter)

@injector.service
def analyse_first(plotter: Plotter):
    plot_something(plotter)

@injector.service
def provide_image_converter() -> ImageConverter:
    return SpecialImageConverter()

@injector.service
def provide_plotter(image_converter: ImageConverter) -> Plotter:
    return MPLPlotter(image_converter)

def main():
    injector.create_and_resister_services()

main()

```

This code is flat; {term}`services<service>` are provided directly to {term}`consumers<consumer>` such that we do not need to pass them down multiple call frames. Because services are constructed as many-to-one components, it's trivial to replace one implementation with another. For example, if we wanted to swap out the matplotlib plotter with a higher ranked plotter, it's as simple as:

```python
@injector.service(rank=100)
def provide_plotly_plotter() -> Plotter:
    return PlotlyPlotter()

```
