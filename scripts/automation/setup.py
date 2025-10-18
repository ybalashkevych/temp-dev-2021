"""
Setup file for cursor-automation package
"""

from setuptools import find_packages, setup

with open("README.md", "r", encoding="utf-8") as fh:
    long_description = fh.read()

setup(
    name="cursor-automation",
    version="1.0.0",
    author="Yurii Balashkevych",
    description="Automated Cursor AI assistant for GitHub PR feedback",
    long_description=long_description,
    long_description_content_type="text/markdown",
    package_dir={"": "src"},
    packages=find_packages(where="src"),
    python_requires=">=3.9",
    install_requires=[
        "PyGithub>=2.1.1",
        "pydantic>=2.5.0",
        "pydantic-settings>=2.1.0",
        "click>=8.1.7",
        "python-dotenv>=1.0.0",
    ],
    extras_require={
        "dev": [
            "pytest>=7.4.3",
            "pytest-mock>=3.12.0",
            "pytest-cov>=4.1.0",
            "black>=23.12.0",
            "mypy>=1.7.0",
            "ruff>=0.1.7",
            "types-requests>=2.31.0",
        ],
    },
    entry_points={
        "console_scripts": [
            "cursor-daemon=cursor_automation.__main__:main",
        ],
    },
    classifiers=[
        "Development Status :: 4 - Beta",
        "Intended Audience :: Developers",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.11",
        "Programming Language :: Python :: 3.12",
    ],
)

