output results {
    value = {
        k_ecs = var.params.k_ecs,
        k_svc = var.params.k_svc,
        k_cnt = var.params.k_cnt,
        values = {
            traefik_id = local.traefik_id
            url = local.url
        }
    }
}