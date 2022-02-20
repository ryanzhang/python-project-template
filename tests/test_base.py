import pytest

from kupy.logger import logger
from project_name import BaseClass, base_function

given = pytest.mark.parametrize


given = pytest.mark.parametrize
skipif = pytest.mark.skipif
skip = pytest.mark.skip
xfail = pytest.mark.xfail

class TestBaseClass:
    @pytest.fixture(scope="class")
    def db(self):
        pass

    @pytest.fixture(autouse=True)
    def setup_teamdown(self):
        logger.info("TestCase Level Setup is triggered!")
        yield
        logger.info("TestCase Level Tear Down is triggered!")
        
    def test_parameterized(self,db):
        b = BaseClass()
        assert b is not None

@given("fn", [BaseClass(), base_function])
def test_parameterized(fn):
    assert "hello from" in fn()


def test_base_function():
    assert base_function() == "hello from base function"


def test_base_class():
    assert BaseClass().base_method() == "hello from BaseClass"
