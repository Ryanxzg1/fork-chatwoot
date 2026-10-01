# frozen_string_literal: true

class Webhooks::LazadaController < ActionController::API
  def events
    raw_post = request.raw_post
    signature = request.headers['Authorization'] || request.headers['X-Lazada-Signature'] || ''

    payload = begin
      JSON.parse(raw_post)
    rescue JSON::ParserError
      params.to_unsafe_hash
    end

    Webhooks::LazadaEventsJob.perform_later(
      params: payload,
      raw_post: raw_post,
      signature: signature
    )

    render json: { success: true }
  end
end
