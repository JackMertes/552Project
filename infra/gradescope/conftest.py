import pytest
import json

cases = []

def pytest_addoption(parser):
    parser.addoption(
        "--results-file",
        action="store",
        default="results.json",
        help="Filename to store test results in Gradescope compatible JSON",
    )

@pytest.hookimpl(hookwrapper=True)
def pytest_runtest_makereport(item, call):
    """
    Hook into each each test phase and collect results.
    """
    outcome = yield
    report = outcome.get_result()

    if report.when == "call":
        cases.append({
            "score": 1 if report.outcome != "failed" else 0,
            "max_score": 1,
            # "status": report.outcome,
            "name": report.nodeid,
            "name_format": "text",
            "visibility": "visible",
        })

@pytest.hookimpl()
def pytest_sessionfinish(session, exitstatus):
    """
    Emit collected results as JSON at end of session.
    """

    filename = session.config.getoption("--results-file")
    results = { "tests": cases }
    with open(filename, "w") as f:
        json.dump(results, f, indent=4)
