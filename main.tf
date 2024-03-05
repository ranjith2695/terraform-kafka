terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "1.64.0"
    }
  }
}

provider "confluent" {
  cloud_api_key    = var.confluent_cloud_api_key    # optionally use CONFLUENT_CLOUD_API_KEY env var
  cloud_api_secret = var.confluent_cloud_api_secret # optionally use CONFLUENT_CLOUD_API_SECRET env var
}

resource "confluent_environment" "dev" {
  display_name = "Dev"

  lifecycle {
    prevent_destroy = true
  }
}
resource "confluent_kafka_cluster" "basic" {
  display_name = "basic_kafka_cluster"
  availability = "SINGLE_ZONE"
  cloud        = "AWS"
  region       = "us-east-2"
  basic {}

    environment {
    id = confluent_environment.dev.id
  }

  lifecycle {
    prevent_destroy = true
  }
}
####-------Information regarding the "app-manager" service account -------
resource "confluent_service_account" "app-manager1" {
  display_name = "app-manager1"
  description  = "Service account to manage Kafka cluster"
}


resource "confluent_role_binding" "app-manager1-kafka-cluster-admin" {
  principal   = "User:${confluent_service_account.app-manager1.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = confluent_kafka_cluster.basic.rbac_crn
}

resource "confluent_api_key" "app-manager1-kafka-api-key" {
  display_name = "app-manager1-kafka-api-key"
  description  = "Kafka API Key that is owned by 'app-manager' service account"
  owner {
    id          = confluent_service_account.app-manager1.id
    api_version = confluent_service_account.app-manager1.api_version
    kind        = confluent_service_account.app-manager1.kind
  }
  managed_resource {
    id          = confluent_kafka_cluster.basic.id
    api_version = confluent_kafka_cluster.basic.api_version
    kind        = confluent_kafka_cluster.basic.kind

    environment {
      id = confluent_environment.dev.id
    }
  }


  depends_on = [
    confluent_role_binding.app-manager1-kafka-cluster-admin
  ]

}


####--------- Creating a Kafka topic -----
resource "confluent_kafka_topic" "order" {
  kafka_cluster {
    id = confluent_kafka_cluster.basic.id
  }
  topic_name         = "order"
  rest_endpoint      = confluent_kafka_cluster.basic.rest_endpoint
  credentials {
    key    = confluent_api_key.app-manager1-kafka-api-key.id
    secret = confluent_api_key.app-manager1-kafka-api-key.secret
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_kafka_topic" "manual1" {
  kafka_cluster {
    id = confluent_kafka_cluster.basic.id
  }
  topic_name         = "manual1"
  partitions_count   = 7
  rest_endpoint      = confluent_kafka_cluster.basic.rest_endpoint
  credentials {
    key    = confluent_api_key.app-manager1-kafka-api-key.id
    secret = confluent_api_key.app-manager1-kafka-api-key.secret
  }

  lifecycle {
    prevent_destroy = true
  }
}
#---- Information regarding the "app-producer1" service account ------
resource "confluent_service_account" "app-producer1" {
  display_name = "app-producer1"
  description  = "Service account to produce to 'orders' topic of 'inventory' Kafka cluster"
}

resource "confluent_api_key" "app-producer-kafka-api-key" {
  display_name = "app-producer1-kafka-api-key"
  description  = "Kafka API Key that is owned by 'app-producer' service account"
  owner {
    id          = confluent_service_account.app-producer1.id
    api_version = confluent_service_account.app-producer1.api_version
    kind        = confluent_service_account.app-producer1.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.basic.id
    api_version = confluent_kafka_cluster.basic.api_version
    kind        = confluent_kafka_cluster.basic.kind

    environment {
      id = confluent_environment.dev.id
    }
  }
}

