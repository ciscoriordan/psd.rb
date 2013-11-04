class PSD
  # Collection of methods that composes two RGBA pixels together
  # in various ways based on Photoshop blend modes.
  #
  # Mostly based on similar code from libpsd.
  module Compose
    extend self

    #
    # Normal blend modes
    #

    # Normal composition, delegate to ChunkyPNG
    def normal(fg, bg, layer)
      return fg if opaque?(fg) || fully_transparent?(bg)
      return bg if fully_transparent?(fg)

      mix_alpha, dst_alpha = calculate_alphas(fg, bg, layer)
      new_r = blend_channel(r(bg), r(fg), mix_alpha)
      new_g = blend_channel(g(bg), g(fg), mix_alpha)
      new_b = blend_channel(b(bg), b(fg), mix_alpha)

      rgba(new_r, new_g, new_b, dst_alpha)
    end

    #
    # Subtractive blend modes
    #

    def darken(fg, bg, layer)
      return fg if opaque?(fg) || fully_transparent?(bg)
      return bg if fully_transparent?(fg)

      mix_alpha, dst_alpha = calculate_alphas(fg, bg, layer)
      new_r = r(fg) <= r(bg) ? blend_channel(r(bg), r(fg), mix_alpha) : r(bg)
      new_g = g(fg) <= g(bg) ? blend_channel(g(bg), g(fg), mix_alpha) : g(bg)
      new_b = b(fg) <= b(bg) ? blend_channel(b(bg), b(fg), mix_alpha) : b(bg)

      rgba(new_r, new_g, new_b, dst_alpha)
    end

    def multiply(fg, bg, layer)
      return fg if opaque?(fg) || fully_transparent?(bg)
      return bg if fully_transparent?(fg)

      mix_alpha, dst_alpha = calculate_alphas(fg, bg, layer)
      new_r = blend_channel(r(bg), r(fg) * r(bg) >> 8, mix_alpha)
      new_g = blend_channel(g(bg), g(fg) * g(bg) >> 8, mix_alpha)
      new_b = blend_channel(b(bg), b(fg) * b(bg) >> 8, mix_alpha)

      rgba(new_r, new_g, new_b, dst_alpha)
    end

    def color_burn(fg, bg, layer)
      return fg if opaque?(fg) || fully_transparent?(bg)
      return bg if fully_transparent?(fg)

      mix_alpha, dst_alpha = calculate_alphas(fg, bg, layer)

      new_r = if r(fg) > 0
        f = ((255 - r(bg)) << 8) / r(fg)
        f = f > 255 ? 0 : (255 - f)
        blend_channel(r(bg), f, mix_alpha)
      else
        r(bg)
      end

      new_g = if g(fg) > 0
        f = ((255 - g(bg)) << 8) / g(fg)
        f = f > 255 ? 0 : (255 - f)
        blend_channel(g(bg), f, mix_alpha)
      else
        g(bg)
      end

      new_b = if b(fg) > 0
        f = ((255 - b(bg)) << 8) / b(fg)
        f = f > 255 ? 0 : (255 - f)
        blend_channel(b(bg), f, mix_alpha)
      else
        b(bg)
      end

      rgba(new_r, new_g, new_b, dst_alpha)
    end

    def linear_burn(fg, bg, layer)
      return fg if opaque?(fg) || fully_transparent?(bg)
      return bg if fully_transparent?(fg)

      mix_alpha, dst_alpha = calculate_alphas(fg, bg, layer)

      new_r = blend_channel(r(bg), r(fg) < (255 - r(bg)) ? 0 : r(fg) - 255 - r(bg), mix_alpha)
      new_g = blend_channel(g(bg), g(fg) < (255 - g(bg)) ? 0 : g(fg) - 255 - g(bg), mix_alpha)
      new_b = blend_channel(b(bg), b(fg) < (255 - b(bg)) ? 0 : b(fg) - 255 - b(bg), mix_alpha)

      rgba(new_r, new_g, new_b, dst_alpha)
    end

    #
    # Additive blend modes
    #

    def lighten(fg, bg, layer)
      return fg if opaque?(fg) || fully_transparent?(bg)
      return bg if fully_transparent?(fg)

      mix_alpha, dst_alpha = calculate_alphas(fg, bg, layer)

      new_r = r(fg) >= r(bg) ? blend_channel(r(bg), r(fg), mix_alpha) : r(bg)
      new_g = g(fg) >= g(bg) ? blend_channel(g(bg), g(fg), mix_alpha) : g(bg)
      new_b = b(fg) >= b(bg) ? blend_channel(b(bg), b(fg), mix_alpha) : b(bg)
      
      rgba(new_r, new_g, new_b, dst_alpha)
    end

    def screen(fg, bg, layer)
      return fg if opaque?(fg) || fully_transparent?(bg)
      return bg if fully_transparent?(fg)

      mix_alpha, dst_alpha = calculate_alphas(fg, bg, layer)

      new_r = blend_channel(r(bg), 255 - ((255 - r(bg)) * (255 - r(fg)) >> 8), mix_alpha)
      new_g = blend_channel(g(bg), 255 - ((255 - g(bg)) * (255 - g(fg)) >> 8), mix_alpha)
      new_b = blend_channel(b(bg), 255 - ((255 - b(bg)) * (255 - b(fg)) >> 8), mix_alpha)

      rgba(new_r, new_g, new_b, dst_alpha)
    end

    def color_dodge(fg, bg, layer)
      return fg if opaque?(fg) || fully_transparent?(bg)
      return bg if fully_transparent?(fg)

      mix_alpha, dst_alpha = calculate_alphas(fg, bg, layer)

      new_r = if r(fg) < 255
        f = [(r(bg) << 8) / (255 - r(fg)), 255].min
        blend_channel(r(bg), f, mix_alpha)
      else
        r(bg)
      end

      new_g = if g(fg) < 255
        f = [(g(bg) << 8) / (255 - g(fg)), 255].min
        blend_channel(g(bg), f, mix_alpha)
      else
        g(bg)
      end

      new_b = if b(fg) < 255
        f = [(b(bg) << 8) / (255 - b(fg)), 255].min
        blend_channel(b(bg), f, mix_alpha)
      else
        b(bg)
      end

      rgba(new_r, new_g, new_b, dst_alpha)
    end

    def linear_dodge(fg, bg, layer)
      return fg if opaque?(fg) || fully_transparent?(bg)
      return bg if fully_transparent?(fg)

      mix_alpha, dst_alpha = calculate_alphas(fg, bg, layer)

      new_r = blend_channel(r(bg), (r(bg) + r(fg)) > 255 ? 255 : r(bg) + r(fg), mix_alpha)
      new_g = blend_channel(g(bg), (g(bg) + g(fg)) > 255 ? 255 : g(bg) + g(fg), mix_alpha)
      new_b = blend_channel(b(bg), (b(bg) + b(fg)) > 255 ? 255 : b(bg) + b(fg), mix_alpha)

      rgba(new_r, new_g, new_b, dst_alpha)
    end


    #
    # Contrasting blend modes
    #

    def overlay(fg, bg, layer)
      return fg if opaque?(fg) || fully_transparent?(bg)
      return bg if fully_transparent?(fg)

      mix_alpha, dst_alpha = calculate_alphas(fg, bg, layer)

      new_r = if r(bg) < 128
        blend_channel(r(bg), r(bg) * r(fg) >> 7, mix_alpha)
      else
        blend_channel(r(bg), 255 - ((255 - r(bg)) * (255 - r(fg)) >> 7), mix_alpha)
      end

      new_g = if g(bg) < 128
        blend_channel(g(bg), g(bg) * g(fg) >> 7, mix_alpha)
      else
        blend_channel(g(bg), 255 - ((255 - g(bg)) * (255 - g(fg)) >> 7), mix_alpha)
      end

      new_b = if b(bg) < 128
        blend_channel(b(bg), b(bg) * b(fg) >> 7, mix_alpha)
      else
        blend_channel(b(bg), 255 - ((255 - b(bg)) * (255 - b(fg)) >> 7), mix_alpha)
      end

      rgba(new_r, new_g, new_b, dst_alpha)
    end

    

    #
    # Inversion blend modes
    #

    def difference(fg, bg)
      return fg if opaque?(fg) || fully_transparent?(bg)
      return bg if fully_transparent?(fg)

      new_r = (r(fg) - r(bg)).abs
      new_g = (g(fg) - g(bg)).abs
      new_b = (b(fg) - b(bg)).abs
      new_a = a(fg) + int8_mult(0xff - a(fg), a(bg))

      rgba(new_r, new_g, new_b, new_a)
    end

    # If the blend mode is missing, we fall back to normal composition.
    def method_missing(method, *args, &block)
      return ChunkyPNG::Color.send(method, *args) if ChunkyPNG::Color.respond_to?(method)
      normal(*args)
    end

    private

    def calculate_alphas (fg, bg, layer)
      opacity = calculate_opacity(layer)
      src_alpha = a(fg) * opacity >> 8
      dst_alpha = a(bg)

      mix_alpha = (src_alpha << 8) / (src_alpha + ((256 - src_alpha) * dst_alpha >> 8))
      dst_alpha = dst_alpha + ((256 - dst_alpha) * src_alpha >> 8)

      return mix_alpha, dst_alpha
    end

    def calculate_opacity(layer)
      layer.opacity * layer.fill_opacity / 255
    end

    def blend_channel(bg, fg, alpha)
      ((bg << 8) + (fg - bg) * alpha) >> 8
    end

    def blend_alpha(bg, fg)
      bg + ((255 - bg) * fg >> 8)
    end
  end
end