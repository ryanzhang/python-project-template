from kupy.config import *
from kupy.logger import logger


def test_properties_been_load():
    logger.info(type(default_setting))
    assert configs is not None
    assert configs.get("postgres_host").data == "pg-quant-invest"
    assert configs["postgres_port"].data == "5432"
    assert configs.get("postgres_user").data == "user"
    assert configs.get("postgres_password").data == "password"
    assert configs.get("postgres_database").data == "market"
    assert configs.get("tus_token").data != ""
    assert configs.get("log_level").data != ""
    assert configs.get("something_not_exists") is None
    assert configs["remote_api_cache_csv"].data == "True"
    assert bool(configs["remote_api_cache_csv"].data)
    assert bool(configs["remote_api_cache_pkl"].data)
    assert not bool(configs["log_output_path"].data)
